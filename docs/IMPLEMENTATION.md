# Flutter Zero-Copy GPU Texture Sharing — 实现文档

> macOS IOSurface 跨进程零拷贝纹理共享 | 2026-06-10

---

## 目录

1. [系统架构](#1-系统架构)
2. [文件详解](#2-文件详解)
3. [零拷贝原理](#3-零拷贝原理)
4. [构建与运行](#4-构建与运行)
5. [调试指南](#5-调试指南)
6. [关键 Bug 与修复](#6-关键-bug-与修复)
7. [平台 API 映射](#7-平台-api-映射)

---

## 1. 系统架构

### 1.1 进程模型

```
┌──────────────────────────────────────────────────────────────────┐
│                      主进程 (Flutter)                              │
│                                                                   │
│  ┌──────────────────────┐     ┌──────────────────────────────┐   │
│  │ Dart Layer            │     │ Native Plugin (Swift)         │   │
│  │                        │     │                               │   │
│  │ ZeroCopyWidget         │     │ ZeroCopyTexturePlugin         │   │
│  │  ├─ MethodChannel ────┼────→│  ├─ IOSurfaceCreate()          │   │
│  │  ├─ Process.start() ──┼──┐  │  ├─ CVPixelBufferCreate()     │   │
│  │  ├─ Texture() widget   │  │  │  ├─ registerTexture()         │   │
│  │  └─ Stack+Positioned   │  │  │  └─ CVDisplayLink (60fps)     │   │
│  └──────────────────────┘  │  └──────────────────────────────┘   │
│                             │                                      │
└─────────────────────────────┼──────────────────────────────────────┘
                              │ surfaceID (32-bit cmdline arg)
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      子进程 (C++ OpenGL)                           │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ cube_renderer (独立可执行文件)                              │   │
│  │  ├─ Headless CGL context (无窗口)                          │   │
│  │  ├─ IOSurfaceLookup(surfaceID) → GL texture (RECTANGLE)   │   │
│  │  ├─ FBO (IOSurface texture = color attachment 0)          │   │
│  │  └─ Render loop: glClear → rotate MVP → glDrawArrays → glFlush │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
└───────────────────────────────────────────────────────────────────┘
                              ▲
              ┌───────────────┴───────────────┐
              │     IOSurface GPU VRAM         │
              │    (同一块物理内存, 零拷贝)       │
              │  Metal 纹理 ◄──→ OpenGL FBO   │
              └───────────────────────────────┘
```

### 1.2 帧同步机制

采用 **CVDisplayLink**（macOS 原生 vsync 回调）驱动帧更新：

```
CVDisplayLink (硬件 vsync, 60Hz)
  │
  ├→ onDisplayLink() callback
  │    └→ textureRegistry.textureFrameAvailable(textureId)
  │         └→ Flutter Engine 调度 raster thread
  │              └→ copyPixelBuffer() → 获取 CVPixelBuffer (IOSurface-backed)
  │                   └→ Impeller 采样 Metal 纹理 → 合成到屏幕
  │
  └→ (同时) cube_renderer 子进程在 glFlush() 后 IOSurface seed 更新
```

**为什么不用 Dart Ticker + MethodChannel：**
- MethodChannel 调用有序列化开销
- Dart → Native 通信不是精确的 vsync 对齐
- CVDisplayLink 直接注册在硬件刷新回调上，延迟最低

---

## 2. 文件详解

### 2.1 `lib/main.dart` — Flutter 应用层

**核心类：`ZeroCopyWidget`**

```dart
ZeroCopyWidget({
  required double width,   // IOSurface 宽度 (px)
  required double height,  // IOSurface 高度 (px)
  required double left,    // 水平偏移
  required double top,     // 垂直偏移
  String? rendererPath,    // 可选: 自定义 cube_renderer 路径
})
```

**生命周期：**

| 阶段 | 操作 |
|------|------|
| `initState()` | MethodChannel.invokeMethod('createSurface') → 获取 surfaceID + textureId |
| | Process.start('cube_renderer', [surfaceID, width, height]) → 启动子进程 |
| `build()` | Positioned + SizedBox + Texture(textureId) + 文字 overlay |
| `dispose()` | kill 子进程 → MethodChannel.invokeMethod('dispose') |

**关键代码路径：**

```dart
// 创建 IOSurface (异步)
final result = await _channel.invokeMethod('createSurface', {
  'width': widget.width.toInt(),
  'height': widget.height.toInt(),
});
_surfaceID = result['surfaceID'];     // 传给子进程
_textureId = result['textureId'];     // 给 Texture widget

// 启动子进程
final exeDir = Directory(Platform.resolvedExecutable).parent;
final path = '${exeDir.path}/cube_renderer';  // app bundle 内
_childProcess = await Process.start(path, [
  _surfaceID.toString(),
  widget.width.toInt().toString(),
  widget.height.toInt().toString(),
]);

// CVDisplayLink 在 native 侧驱动帧更新，无需 Dart Ticker
```

### 2.2 `macos/Runner/ZeroCopyTexturePlugin.swift` — Native 插件

**注册入口：**
```swift
static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
        name: "com.snapmaker.zero_copy/texture",
        binaryMessenger: registrar.messenger)
    let instance = ZeroCopyTexturePlugin()
    instance.textureRegistry = registrar.textures  // 获取 TextureRegistry
    registrar.addMethodCallDelegate(instance, channel: channel)
}
```

**IOSurface 创建流程：**

```swift
// 1. 创建 IOSurface (GPU VRAM 分配)
let props: [String: Any] = [
    kIOSurfaceWidth: width,
    kIOSurfaceHeight: height,
    kIOSurfaceBytesPerElement: 4,
    kIOSurfaceBytesPerRow: width * 4,
    kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA,  // BGRA8
    kIOSurfaceIsGlobal: true,  // 允许子进程通过 ID 查找
]
let surface = IOSurfaceCreate(props as CFDictionary)!
let surfaceID = IOSurfaceGetID(surface)  // 32-bit 句柄

// 2. 包装为 CVPixelBuffer (零拷贝)
var cvOut: Unmanaged<CVPixelBuffer>?
CVPixelBufferCreateWithIOSurface(nil, surface, nil, &cvOut)
pixelBuffer = cvOut!.takeRetainedValue()

// 3. 注册到 Flutter TextureRegistry
textureId = textureRegistry!.register(self)
// textureId 是一个指针值 (e.g., 0x97DC8E00 = 35317628864)

// 4. 启动 CVDisplayLink (硬件 vsync 回调)
CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
CVDisplayLinkSetOutputCallback(displayLink, callback, selfPtr)
CVDisplayLinkStart(displayLink)
```

**CVDisplayLink 回调：**
```swift
private func onDisplayLink() {
    if textureId != 0 {
        textureRegistry?.textureFrameAvailable(textureId)
        // Flutter 引擎收到通知后:
        //   1. 调度 raster thread
        //   2. 调用 copyPixelBuffer()
        //   3. 从 CVPixelBuffer 创建/更新 Metal 纹理
        //   4. Impeller 合成到屏幕
    }
}
```

**注意：** `registrar.textures.register(self)` 的 ObjC 方法名是 `registerTexture:`，但在 Swift 中被重命名为 `register(_:)`。

### 2.3 `cube_renderer/main.cpp` — C++ OpenGL 渲染器

**关键 API 调用链：**

```
main(argc, argv)
  │
  ├─ 1. 创建 Headless GL Context
  │    CGLChoosePixelFormat(attrs, &pix, &npix)
  │    CGLCreateContext(pix, NULL, &ctx)  // NULL = 无窗口!
  │    CGLSetCurrentContext(ctx)
  │
  ├─ 2. 绑定 IOSurface (零拷贝核心!)
  │    IOSurfaceLookup(surfaceID)            // 查找共享 GPU 内存
  │    glGenTextures(1, &tex)
  │    CGLTexImageIOSurface2D(              // 绑定到 GL 纹理
  │        ctx,
  │        GL_TEXTURE_RECTANGLE,             // 注意: RECTANGLE, 不是 2D!
  │        GL_RGBA8, w, h,
  │        GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV,
  │        surface, 0)
  │
  ├─ 3. 创建 FBO
  │    glGenFramebuffers(1, &fbo)
  │    glFramebufferTexture2D(..., tex, 0)  // IOSurface = color attachment
  │    glGenRenderbuffers(1, &depth)        // IOSurface 不含深度缓冲
  │    glFramebufferRenderbuffer(..., depth)
  │
  ├─ 4. 设置立方体几何
  │    glGenVertexArrays(1, &vao)
  │    glGenBuffers(1, &vbo)
  │    36 vertices (12 triangles × 3) with position + color per vertex
  │    Compile GLSL vertex + fragment shaders (Core Profile)
  │
  └─ 5. 渲染循环
       while (running) {
           glBindFramebuffer(GL_FRAMEBUFFER, fbo)
           glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
           glEnable(GL_DEPTH_TEST)
           computeMVP(mvp, angle, w, h)          // 计算 MVP 矩阵
           glUniformMatrix4fv(uMVP, 1, GL_FALSE, mvp)  // GL_FALSE = 列主序
           glDrawArrays(GL_TRIANGLES, 0, 36)
           glFlush()                              // 更新 IOSurface seed
           usleep(16667)                          // ~60fps
       }
```

**为什么用 `GL_TEXTURE_RECTANGLE` 而不是 `GL_TEXTURE_2D`：**
- IOSurface 的 `CGLTexImageIOSurface2D` 要求 `GL_TEXTURE_RECTANGLE_ARB` target
- `GL_TEXTURE_RECTANGLE` 使用非归一化纹理坐标 (0..w, 0..h)，不需要 mipmap
- 对离屏渲染 (FBO) 最合适

### 2.4 `cube_renderer/CMakeLists.txt` — 构建配置

```cmake
cmake_minimum_required(VERSION 3.16)
project(cube_renderer LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
add_executable(cube_renderer main.cpp)
target_link_libraries(cube_renderer
    "-framework OpenGL"
    "-framework IOSurface"
    "-framework CoreVideo"
    "-framework CoreFoundation"
)
```

### 2.5 `build_cube_renderer.sh` — 一键编译

自动查找 cmake 路径（支持 `/Applications/CMake.app`），编译 C++ 并输出到 `cube_renderer/build/cube_renderer`。

---

## 3. 零拷贝原理

### 3.1 内存模型

```
进程 A (Flutter)                    进程 B (cube_renderer)
──────────────────                  ──────────────────────
虚拟地址: 0x7F_1000                 虚拟地址: 0x7F_5000
     │                                    │
     └──────────┬─────────────────────────┘
                │
        页表映射 │ (MMU)
                │
     ┌──────────▼──────────┐
     │  物理地址: 0xA000    │
     │  IOSurface VRAM     │
     │  800×600×4 = 1.92MB │
     └─────────────────────┘
```

### 3.2 每帧数据路径

```
有拷贝方案 (PlatformView / CPU readback):
═══════════════════════════════════════════════════
  glReadPixels → CPU mem (2-4ms)
  IPC serialization (1-2ms)
  IPC deserialization (1-2ms)
  decodeImageFromPixels → GPU upload (2-4ms)
  ─────────────────────────────────
  总计: 8-15ms → 帧预算 16.6ms → 只剩 1-8ms → FPS 15-25

零拷贝方案 (IOSurface):
═══════════════════════════════════════════════════
  glFlush → IOSurface seed (硬件原子操作, <0.01ms)
  CVDisplayLink → textureFrameAvailable (<0.1ms)
  Impeller 采样 Metal 纹理 (0ms — 本来就是 GPU 采样)
  ─────────────────────────────────
  总计: <0.1ms → 帧预算剩余 16.5ms → FPS 55-60
```

### 3.3 验证方法

```swift
// 在 IOSurface 创建后、cube_renderer 渲染前:
IOSurfaceLock(surface, [], nil)
let ptr = IOSurfaceGetBaseAddress(surface).bindMemory(to: UInt32.self, ...)
ptr[0] = 0xFF00FFFF  // 填充品红色
IOSurfaceUnlock(surface, [], nil)
// → Flutter 端应看到品红色矩形 → 证明纹理管线工作

// 在 cube_renderer 渲染 2 秒后读回像素:
IOSurfaceLock(surface, [], nil)
let topLeft = ptr[0]           // 0xff262659 → 背景色 (深灰蓝)
let center  = ptr[225*w+300]   // 0xff33cc33 → 立方体绿色面!
IOSurfaceUnlock(surface, [], nil)
// → 非背景色的中心像素证明立方体渲染成功
```

---

## 4. 构建与运行

### 4.1 环境要求

- macOS 15+ (Apple Silicon)
- Flutter 3.24+ (fvm)
- Xcode 26+ (Command Line Tools)
- CMake 3.16+

### 4.2 构建步骤

```bash
# 1. 编译 C++ 渲染器
bash build_cube_renderer.sh

# 2. 编译并运行 Flutter 应用
fvm flutter run -d macos

# 或使用 VS Code:
# F5 → 选择 "macOS (Debug — no build)"
```

### 4.3 VS Code 调试配置

`.vscode/launch.json`:
```json
{
    "name": "macOS (Debug + Build C++)",
    "type": "dart",
    "request": "launch",
    "program": "lib/main.dart",
    "deviceId": "macos",
    "flutterMode": "debug",
    "preLaunchTask": "Build cube_renderer"
}
```

`.vscode/tasks.json`:
```json
{
    "label": "Build cube_renderer",
    "type": "shell",
    "command": "bash",
    "args": ["${workspaceFolder}/build_cube_renderer.sh"]
}
```

### 4.4 发布模式 (Release)

```bash
# 编译 C++
bash build_cube_renderer.sh

# 编译 Flutter Release
fvm flutter build macos --release

# 复制 cube_renderer 到 app bundle
cp cube_renderer/build/cube_renderer \
   build/macos/Build/Products/Release/flutter_zero_copy.app/Contents/MacOS/

# 运行
open build/macos/Build/Products/Release/flutter_zero_copy.app
```

---

## 5. 调试指南

### 5.1 验证 IOSurface 创建

查看 Flutter 控制台输出 (Xcode Console 或 `flutter run` 终端):

```
[ZeroCopyPlugin] Created IOSurface: id=970, 600x450     ← 应出现
[ZeroCopyPlugin] Registered texture: id=35317628864       ← 非 0 值
[ZeroCopyPlugin] CVDisplayLink started                     ← CVDisplayLink 启动
flutter: [ZeroCopy] surfaceID=970 textureId=35317628864  ← Dart 确认
```

### 5.2 验证子进程启动

```bash
ps aux | grep cube_renderer
# 应看到: cube_renderer 970 600 450
```

### 5.3 验证渲染管线

使用独立测试脚本 (无需 Flutter):

```bash
# 创建 test_surface.swift (见 3.3 节)
swiftc -o test_surface test_surface.swift \
    -framework IOSurface -framework CoreVideo
./test_surface

# 预期输出:
# Center pixel: 0xff33cc33  ← 非背景色, 证明立方体渲染成功
```

### 5.4 常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 只看到灰色背景，无立方体 | MVP 矩阵计算错误 | 检查 `computeMVP` 列主序乘法 |
| 应用启动后无任何矩形 | IOSurface 未显示 | 检查 `registerTexture` 返回值 ≠ 0 |
| 品红色一闪而过，之后灰色 | IOSurface 创建成功但立方体不可见 | 检查 MVP 矩阵投影坐标 (应为 NDC ∈ [-1,1]) |
| cube_renderer 启动后立即退出 | IOSurfaceLookup 失败 | 检查 `kIOSurfaceIsGlobal` = true |

---

## 6. 关键 Bug 与修复

### Bug 1: 矩阵乘法索引错误

**症状**: 立方体渲染不可见，仅显示灰色背景

**诊断**: 打印 MVP 矩阵和投影坐标:
```
MVP row3: [0.000, 0.000, -1.000, 0.000]  ← clip_w 恒为 0!
Projected ndc=(-1.81, -2.41)  ← 在屏幕外!
```

**原因**: `computeMVP` 的矩阵乘法 `mul` 函数使用了行主序索引访问列主序矩阵:
```cpp
// 错误: a[i*4+k] 是行主序访问
out[i * 4 + j] += a[i * 4 + k] * b[k * 4 + j];
```

**修复**: 改用列主序索引:
```cpp
// 正确: col*4+row 是列主序访问
out[col * 4 + row] += a[k * 4 + row] * b[col * 4 + k];
```

**教训**: 在 C/C++ 中手写矩阵运算时，明确注释存储顺序；优先使用 GLM 等成熟库。

### Bug 2: FlutterTextureRegistry 方法名混淆

**症状**: 纹理注册返回异常大的 ID (`40791579776`)

**原因**: ObjC 方法 `registerTexture:` 在 Swift 中被重命名为 `register(_:)`。调用 `registerTexture(self)` 会编译失败。

**修复**: 使用正确的 Swift 方法名 `register(self)`。

### Bug 3: CVDisplayLink vs Ticker 选择

**初始方案**: Dart Ticker → MethodChannel('textureFrameAvailable') → Native

**问题**: 
- MethodChannel 有序列化开销
- Ticker 回调与硬件 vsync 不完全对齐
- 调试时很难确认调用链

**最终方案**: Native CVDisplayLink 直接驱动 `textureFrameAvailable()`
- 硬件 vsync 精确同步
- 无序列化开销
- 代码更简洁

---

## 7. 平台 API 映射

### 7.1 零拷贝纹理共享原语

| 概念 | macOS | Windows | Linux |
|------|-------|---------|-------|
| 共享 GPU 内存 | `IOSurface` | D3D11 Shared Resource | DMA-BUF |
| 跨进程句柄 | `surfaceID` (uint32) | NT Handle | file descriptor |
| 句柄传递 | 命令行参数 | `DuplicateHandle` | `SCM_RIGHTS` (Unix Socket) |
| Flutter GPU API | Metal | D3D11 | Vulkan |
| 子进程 GPU API | OpenGL | OpenGL | OpenGL |

### 7.2 macOS API 调用链

```
Swift (Flutter Plugin)          C++ (Child Process)
─────────────────────          ───────────────────
IOSurfaceCreate(props)          IOSurfaceLookup(id)
  → IOSurfaceRef                  → IOSurfaceRef
IOSurfaceGetID(ref)             CGLTexImageIOSurface2D(ctx, ...)
  → uint32_t                      → GL 纹理绑定到 IOSurface (零拷贝!)

CVPixelBufferCreateWithIOSurface(...)
  → CVPixelBuffer (IOSurface-backed, 零拷贝!)

FlutterTextureRegistry.register(self)
  → Int64 textureId

CVDisplayLink → textureFrameAvailable(id)
  → Flutter 重新采样纹理

GPU 层面:
  Metal 纹理 ◄── IOSurface VRAM ──► OpenGL GL 纹理
  (Impeller 读取)                 (glDrawArrays 写入)
```

### 7.3 关键常量

| 常量 | 值 | 说明 |
|------|------|------|
| `kCVPixelFormatType_32BGRA` | — | BGRA 8-8-8-8, Apple Silicon 原生格式 |
| `kCGLPFAOpenGLProfile` | — | 指定 OpenGL Profile 版本 |
| `kCGLOGLPVersion_3_2_Core` | — | Core Profile 3.2 (macOS 最低要求) |
| `GL_TEXTURE_RECTANGLE` | 0x84F5 | IOSurface 绑定的纹理 target |
| `GL_RGBA8` | 0x8058 | 内部纹理格式 |
| `GL_BGRA` | 0x80E1 | 像素传输格式 (匹配 IOSurface) |
| `GL_UNSIGNED_INT_8_8_8_8_REV` | 0x8367 | BGRA 字节序 (little-endian) |

---

## 参考

- [Apple IOSurface Documentation](https://developer.apple.com/documentation/iosurface)
- [CGLTexImageIOSurface2D](https://developer.apple.com/documentation/opengl/1506112-cglteximageiosurface2d)
- [Flutter Texture Widget](https://api.flutter.dev/flutter/widgets/Texture-class.html)
- [Flutter macOS Texture Sharing](https://docs.flutter.dev/platform-integration/macos/texture-sharing)
