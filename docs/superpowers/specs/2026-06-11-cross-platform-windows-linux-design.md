# Cross-Platform Zero-Copy GPU Texture — Windows + Linux 移植设计

> 对抗审查后的完整方案 | 2026-06-11

---

## 目录

1. [平台矩阵](#1-平台矩阵)
2. [架构概览](#2-架构概览)
3. [渲染器抽离](#3-渲染器抽离-cube_renderer)
4. [各平台零拷贝路径](#4-各平台零拷贝路径)
5. [Flutter Plugin 结构](#5-flutter-plugin-结构)
6. [Dart 端改动](#6-dart-端改动)
7. [构建系统](#7-构建系统-cmake)
8. [纹理格式验证](#8-纹理格式验证)
9. [已知风险 & 实施前验证](#9-已知风险--实施前验证)
10. [分阶段实施](#10-分阶段实施)
11. [对抗审查记录](#11-对抗审查记录)

---

## 1. 平台矩阵

| | macOS (x86_64+arm64) | Windows (x64+ARM64) | Linux (x86_64+aarch64) |
|---|---|---|---|
| **GPU API** | CGL (OpenGL 3.2 Core) | D3D11 (Feature Level 11_0) | EGL (OpenGL ES 3.0) |
| **纹理共享机制** | IOSurface | D3D11 Shared NTHANDLE | DMA-BUF / EGLImage (Wayland) |
| **Flutter 纹理 API** | `FlutterTextureRegistry` (Swift) | `FlutterTextureRegistrar` (C++) | `FlutterDesktopTextureRegistrar` (C) |
| **帧同步** | `CVDisplayLink` (硬件 vsync) | DWM vsync timer | frame timer |
| **Renderer 源文件** | `renderer_macos.mm` (ObjC++) | `renderer_windows.cpp` | `renderer_linux.cpp` |
| **Min OS 版本** | macOS 12 | Windows 8 / Windows 10 | Ubuntu 22.04+ |

### 未来预留

| 维度 | 当前 | 演进方向 |
|------|------|---------|
| macOS GPU | CGL (OpenGL) | Metal 路径预留 `USE_METAL` 编译开关 |
| Flutter 渲染后端 | 各平台原生 (Metal/DirectX/GL) | Impeller Vulkan 后端 (experimental) |
| Linux 纹理 | DMA-BUF (Wayland) | X11 CPU fallback 已内置 |

---

## 2. 架构概览

```
┌──────────────────────────────────────────────────────────────────┐
│                    Dart 侧 (跨平台，不变)                           │
│                                                                   │
│  ZeroCopyWidget                                                   │
│  ├─ MethodChannel ("com.snapmaker.zero_copy/texture")             │
│  ├─ Process.start(renderer)  ← 平台感知路径                       │
│  ├─ Texture(textureId)                                            │
│  └─ GestureDetector → stdin JSON commands                         │
│                                                                   │
└──────────────────┬──────────────────┬──────────────────────────────┘
                   │                  │
    ┌──────────────▼────┐  ┌──────────▼───────────┐  ┌──────────────┐
    │ macOS Plugin      │  │ Windows Plugin       │  │ Linux Plugin │
    │ (Swift, 已有)     │  │ (C++, 新建)          │  │ (C++, 新建)  │
    │ IOSurface         │  │ D3D11 Shared Texture │  │ DMA-BUF/CPU  │
    │ CVPixelBuffer     │  │ FlutterTextureReg.   │  │ FB Texture   │
    │ CVDisplayLink     │  │ DWM Timer            │  │ frame timer  │
    └──────┬────────────┘  └──────┬───────────────┘  └──────┬───────┘
           │                      │                         │
    ┌──────▼──────────────────────▼─────────────────────────▼──────┐
    │                   cube_renderer (C++ 重构)                      │
    │                                                                │
    │  main.cpp           平台无关 (Camera, arcball, JSON, main loop) │
    │  renderer.h         抽象接口 IRenderer                          │
    │  renderer_macos.mm  CGL + IOSurface                            │
    │  renderer_windows.cpp D3D11 Shared NTHANDLE                    │
    │  renderer_linux.cpp EGL DMA-BUF + CPU fallback                 │
    │  shaders/           GLSL (macOS/Linux) + HLSL (Windows)        │
    │                                                                │
    └────────────────────────────────────────────────────────────────┘
```

### IRenderer 抽象接口

```cpp
// renderer.h
struct RendererConfig {
    uint64_t shareHandle;  // IOSurface ID / D3D11 HANDLE / DMA-BUF fd
    int width, height;
    int devicePixelRatio;  // 1 = logical pixel (for HiDPI)
};

class IRenderer {
public:
    virtual ~IRenderer() = default;
    virtual bool init(const RendererConfig& cfg) = 0;
    virtual void renderFrame(const Camera& cam) = 0;
    virtual void shutdown() = 0;
    virtual const char* backendName() const = 0;
    // 纹理格式，用于端到端验证
    virtual int pixelFormat() const = 0;
};

// 工厂方法 — 每个平台链接自己的实现
std::unique_ptr<IRenderer> createRenderer();
```

### main.cpp 主循环 (平台无关)

```cpp
int main(int argc, char* argv[]) {
    setvbuf(stdout, NULL, _IONBF, 0);         // stdout unbuffered (pipe to Flutter)

    // Parse args (platform-agnostic)
    uint64_t surfaceID = parseSurfaceArg(argv);
    int width = parseWidthArg(argv);
    int height = parseHeightArg(argv);

    // Platform-specific renderer (resolved at link time)
    auto renderer = createRenderer();
    RendererConfig cfg = {surfaceID, width, height, 1};
    if (!renderer->init(cfg)) {
        fprintf(stderr, "Renderer init failed (%s)\n", renderer->backendName());
        return 1;
    }
    printf("[cube_renderer] Backend: %s | %dx%d\n", renderer->backendName(), width, height);

    // stdin non-blocking for commands
    fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);

    // ── Render loop ──
    while (g_running) {
        readCommands(g_camera);                    // stdin JSON → Camera state
        updateAutoRotation(g_camera, 0.0167f);     // auto-rotate if enabled
        renderer->renderFrame(g_camera);            // platform-specific draw
        usleep(16667);                              // ~60fps
    }

    renderer->shutdown();
    return 0;
}
```

---

## 3. 渲染器抽离 (cube_renderer)

### 代码组织

```
cube_renderer/
├── main.cpp              # 平台无关: Camera, arcball, JSON, 顶点数据, main loop
├── renderer.h            # IRenderer 接口 + RendererConfig
├── renderer_utils.h      # 共享: arcball math (vec3/Quat), 顶点数据 (36 vertices)
├── renderer_macos.mm     # ObjC++: CGL context + IOSurface binding + FBO
├── renderer_windows.cpp  # C++: D3D11 device + shared texture + render target
├── renderer_linux.cpp    # C++: EGL context + DMA-BUF import or CPU fallback
├── shaders/
│   ├── cube.vert          # GLSL vertex (macOS + Linux 共用)
│   ├── cube.frag          # GLSL fragment
│   └── cube.hlsl          # HLSL (Windows, 功能等价于 GLSL pair)
├── CMakeLists.txt         # 单文件, 全平台 + 全架构
└── build_cube_renderer.sh # 跨平台构建脚本
```

### 各 Renderer 关键 API 调用

#### renderer_macos.mm (ObjC++)

```
init:
  CGLChoosePixelFormat(..., kCGLOGLPVersion_3_2_Core, ...)
  CGLCreateContext(...)  // nullptr = offscreen
  CGLSetCurrentContext(...)
  IOSurfaceLookup(surfaceID)
  CGLTexImageIOSurface2D(GL_TEXTURE_RECTANGLE, GL_RGBA8, ..., GL_BGRA, ...)
  glGenFramebuffers → FBO → glFramebufferTexture2D(GL_TEXTURE_RECTANGLE)

renderFrame:
  glBindFramebuffer(FBO)
  glClear + glDrawArrays(36 vertices)
  glFlush()  → IOSurface seed 更新 → Flutter 可见

shutdown:
  delete FBO, delete texture, CGLDestroyContext, CFRelease(IOSurface)
```

#### renderer_windows.cpp

```
init:
  D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, ..., &device, &context)
  HRESULT hr = device->OpenSharedResource((HANDLE)cfg.shareHandle, IID_ID3D11Texture2D, &texture);
  if (FAILED(hr)) → fatal
  device->CreateRenderTargetView(texture, ..., &rtv)
  Compile HLSL shaders → ID3D11VertexShader + ID3D11PixelShader

renderFrame:
  context->OMSetRenderTargets(1, &rtv, nullptr)
  context->ClearRenderTargetView(rtv, clearColor)
  context->Draw(36, 0)   // cube vertices via vertex buffer
  context->Flush()        // 提交到 GPU → 共享纹理可见

shutdown:
  release RTV, texture, shaders, device, context
```

**注意**: `ID3D11Device::OpenSharedResource` 接受 `HANDLE`（来自 `CreateSharedHandle` 的 NT handle）。
跨进程使用时，另一个进程通过 `DuplicateHandle` 或直接传递 handle 值。

#### renderer_linux.cpp

```
detectBestPath:
  wayland = getenv("WAYLAND_DISPLAY")
  hasDmaBuf = eglQueryString(display, EGL_EXTENSIONS) contains "EGL_EXT_image_dma_buf_import"
  → DMA_BUF or CPU_FALLBACK

DMA_BUF path:
  eglGetDisplay(EGL_DEFAULT_DISPLAY) → eglInitialize
  eglChooseConfig + eglCreatePbufferSurface → offscreen surface
  eglBindAPI(EGL_OPENGL_ES_API) → eglCreateContext
  eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, ..., fd, ...) → EGLImage
  glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, eglImage)
  glGenFramebuffers → FBO → glFramebufferTexture2D

CPU_FALLBACK path:
  glReadPixels(..., GL_RGBA, GL_UNSIGNED_BYTE, cpuBuffer)
  // 通过 FlutterDesktopPixelBuffer 提交给 Flutter
  fprintf(stderr, "[cube_renderer] WARNING: Using CPU fallback (not zero-copy)\n");
```

---

## 4. 各平台零拷贝路径

### macOS (已有，不变)

```
Flutter Plugin (Swift):
  IOSurfaceCreate(props) → IOSurfaceGetID() → surfaceID
  CVPixelBufferCreateWithIOSurface(surface) → pixelBuffer
  textureRegistry.register(FlutterTexture) → textureId
  CVDisplayLink → onDisplayLink() → textureFrameAvailable(textureId)

C++ Renderer:
  IOSurfaceLookup(surfaceID) → GL texture (CGLTexImageIOSurface2D) → FBO
  render → glFlush() → IOSurface seed 更新

Flutter Engine:
  copyPixelBuffer() → CVPixelBuffer (backed by IOSurface) → Impeller Metal 采样
  0 copies, GPU VRAM 共享
```

### Windows

```
Flutter Plugin (C++):
  D3D11CreateDevice → device
  CreateTexture2D(..., MiscFlags=SHARED_NTHANDLE, ...) → texture
  device->CreateSharedHandle(texture, ..., &sharedHandle) → HANDLE
  FlutterTextureRegistrar::RegisterTexture(sharedHandle) → textureId
  DWM timer → textureFrameAvailable(textureId)

C++ Renderer:
  device->OpenSharedResource(handle, IID_ID3D11Texture2D, &texture)
  CreateRenderTargetView(texture) → RTV
  render → context->Flush() → GPU 可见

Flutter Engine:
  Impeller DirectX 后端 → 直接采样 D3D11 共享纹理
  0 copies, GPU VRAM 共享
```

### Linux

```
DMA_BUF path (Wayland only):
  Flutter Plugin (C):
    gbm_bo_create(device, width, height, GBM_FORMAT_XBGR8888, GBM_BO_USE_RENDERING)
    gbm_bo_get_fd(bo) → DMA-BUF fd
    FlutterDesktopTextureRegistrar::RegisterTexture(fd) → textureId
    frame timer → textureFrameAvailable(textureId)

  C++ Renderer:
    eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, ..., fd, ...) → EGLImage
    glEGLImageTargetTexture2DOES → GL texture → FBO
    render → glFlush() → DMA-BUF 更新

  Flutter Engine:
    Impeller GL 后端 → 采样 EGLImage 纹理
    0 copies, GPU VRAM 共享

CPU fallback path (X11 / 无 DMA-BUF):
  C++ Renderer:
    glReadPixels() → CPU buffer → stdout pipe
  Flutter Plugin:
    FlutterDesktopPixelBuffer → textureFrameAvailable
    不是零拷贝, 打印 WARNING 日志
```

---

## 5. Flutter Plugin 结构

### 文件布局

```
macos/Runner/
└── ZeroCopyTexturePlugin.swift  # (已有, 不变)

windows/runner/
├── zero_copy_plugin.cpp         # Windows 插件实现
└── zero_copy_plugin.h           # Windows 插件头文件

linux/runner/
├── zero_copy_plugin.cc          # Linux 插件实现
└── zero_copy_plugin.h           # Linux 插件头文件
```

### Windows Plugin 核心逻辑

```cpp
// zero_copy_plugin.h
class ZeroCopyTexturePlugin : public flutter::Plugin {
public:
    static void RegisterWithRegistrar(flutter::PluginRegistrar* registrar);
    void HandleMethodCall(const flutter::MethodCall<>& call,
                          std::unique_ptr<flutter::MethodResult<>> result);
private:
    struct Surface {
        int64_t surfaceId;
        Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
        HANDLE sharedHandle;
        int64_t textureId;
        int width, height;
    };
    std::unordered_map<int64_t, Surface> surfaces_;
    Microsoft::WRL::ComPtr<ID3D11Device> device_;
};
```

### Windows 纹理注册

```cpp
// 1. 创建 D3D11 设备 (与 Flutter Engine 同一个 GPU 适配器)
D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                  D3D11_CREATE_DEVICE_BGRA_SUPPORT, ..., &device_, ...);

// 2. 创建共享纹理
D3D11_TEXTURE2D_DESC desc = {};
desc.Width = width; desc.Height = height;
desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;   // 与 Impeller DirectX 后端匹配
desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED_NTHANDLE;

device_->CreateTexture2D(&desc, nullptr, &texture);

// 3. 获取共享 handle
Microsoft::WRL::ComPtr<IDXGIResource1> dxgiResource;
texture.As(&dxgiResource);
dxgiResource->CreateSharedHandle(nullptr, GENERIC_ALL, nullptr, &sharedHandle);

// 4. 注册到 Flutter
// FlutterTextureRegistrar::RegisterTexture() — API 待验证
```

### Linux Plugin 核心逻辑

```cpp
// zero_copy_plugin.cc
struct Surface {
    int64_t surfaceId;
    int dmaBufFd;           // DMA-BUF fd, -1 if CPU fallback
    int64_t textureId;
    int width, height;
    bool isDirectRender;    // true = DMA-BUF, false = CPU fallback
};
```

**重要**: Flutter Linux 的 `FlutterDesktopTextureRegistrar` API 功能需要**提前验证** — 不确定它支持外部 GPU 纹理还是只接受 CPU pixel buffer。如果只支持 CPU pixel buffer，Linux 的 DMA-BUF 路径就走不通，需要 find 其他方案。

---

## 6. Dart 端改动

**改动极小**，只在进程启动路径和 capabilities 查询处做平台分派。

```dart
import 'dart:io' show Platform;

String _rendererPath() {
  if (Platform.isMacOS) {
    return 'cube_renderer/build/cube_renderer';        // universal binary
  } else if (Platform.isWindows) {
    return r'cube_renderer\build\Release\cube_renderer.exe';
  } else if (Platform.isLinux) {
    return 'cube_renderer/build/cube_renderer';
  }
  throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
}

// 其他零逻辑变更:
// - MethodChannel "com.snapmaker.zero_copy/texture" (共享)
// - Texture(textureId) widget (共享)
// - GestureDetector + stdin JSON (共享)
// - capabilities 方法新增 "textureFormat" 字段
```

### capabilities 查询

```dart
// macOS:
{'textureFormat': 'BGRA8', 'platform': 'macos', ...}

// Windows:
{'textureFormat': 'BGRA8', 'platform': 'windows', ...}

// Linux:
{'textureFormat': 'RGBA8', 'platform': 'linux', 'renderPath': 'dma_buf' | 'cpu_fallback', ...}
```

---

## 7. 构建系统 (CMake)

### 单文件 CMakeLists.txt 结构

```cmake
cmake_minimum_required(VERSION 3.16)
project(cube_renderer LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)

# ── 共享源文件 (所有平台) ──────────────────
set(SHARED_SRC main.cpp)

# ── 平台检测 & 条件编译 ─────────────────────
if(APPLE)
    # macOS universal binary (arm64 + x86_64)
    set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "")
    set(RENDERER_SRC renderer_macos.mm)
    add_executable(cube_renderer ${SHARED_SRC} ${RENDERER_SRC})
    target_link_libraries(cube_renderer
        "-framework OpenGL" "-framework IOSurface"
        "-framework CoreVideo" "-framework CoreFoundation"
    )
    set_target_properties(cube_renderer PROPERTIES
        MACOSX_BUNDLE FALSE  # 不是 app bundle, 纯可执行文件
        OUTPUT_NAME "cube_renderer"
    )

elseif(WIN32)
    # 为 x64 和 ARM64 分别构建 (通过 CMAKE_GENERATOR_PLATFORM)
    set(RENDERER_SRC renderer_windows.cpp)
    add_executable(cube_renderer ${SHARED_SRC} ${RENDERER_SRC})
    target_link_libraries(cube_renderer d3d11.lib dxgi.lib)
    set_target_properties(cube_renderer PROPERTIES
        WIN32_EXECUTABLE TRUE   # /SUBSYSTEM:WINDOWS (不弹控制台)
    )

else()
    # Linux
    set(RENDERER_SRC renderer_linux.cpp)
    add_executable(cube_renderer ${SHARED_SRC} ${RENDERER_SRC})
    find_package(PkgConfig REQUIRED)
    pkg_check_modules(EGL REQUIRED egl)
    pkg_check_modules(GBM REQUIRED gbm)
    target_link_libraries(cube_renderer ${EGL_LIBRARIES} ${GBM_LIBRARIES})
endif()
```

### Windows 多架构

```powershell
# x64
cmake -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release

# ARM64
cmake -B build_arm64 -G "Visual Studio 17 2022" -A ARM64
cmake --build build_arm64 --config Release
```

### macOS Universal Binary

```bash
# 自动双架构 (CMAKE_OSX_ARCHITECTURES = arm64;x86_64)
cmake -B build -G "Unix Makefiles"
cmake --build build

# 验证
lipo -info build/cube_renderer
# 输出: Architectures in the fat file: arm64 x86_64
```

### Linux 多架构

```bash
# x86_64
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build

# aarch64 (交叉编译或 native)
cmake -B build_arm64 -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_TOOLCHAIN_FILE=cmake/aarch64-linux-gnu.cmake
cmake --build build_arm64
```

---

## 8. 纹理格式验证

零拷贝路径对纹理格式敏感。不同平台的格式差异可能导致隐式拷贝。

### 格式矩阵

| 平台 | 创建格式 | Impeller 期望 | 已验证匹配 |
|------|---------|--------------|-----------|
| macOS | `kCVPixelFormatType_32BGRA` | 同上 (Metal 直接) | ✅ |
| Windows | `DXGI_FORMAT_B8G8R8A8_UNORM` | 同上 (DirectX) | ✅ 需实测 |
| Linux DMA-BUF | `GBM_FORMAT_XBGR8888` | `GL_RGBA8` | ⚠️ X vs A 通道差异 |
| Linux CPU | `GL_RGBA` | 原始像素 | ⚠️ |


### 防止隐式拷贝的措施

1. **编译期检查** (macOS/Linux GLSL shader):
   ```glsl
   // 确保 shader 输出格式与纹理格式一致
   // macOS: BGRA → 顶点颜色实际上是 RGB, 着色器输出 RGB
   ```

2. **运行时检查** (Windows):
   ```cpp
   ID3D11Texture2D* incoming;
   D3D11_TEXTURE2D_DESC desc;
   incoming->GetDesc(&desc);
   if (desc.Format != DXGI_FORMAT_B8G8R8A8_UNORM) {
       fprintf(stderr, "[WARN] Unexpected texture format: 0x%x\n", desc.Format);
   }
   ```

3. **Dart 侧 capabilities**:
   ```dart
   final caps = await channel.invokeMethod('capabilities');
   assert(caps['textureFormat'] == expectedFormat, 'Texture format mismatch!');
   ```

---

## 9. 已知风险 & 实施前验证

### 🔴 必须在动工前验证

| # | 风险 | 验证方法 | 阻塞阶段 |
|---|------|---------|---------|
| 1 | **Flutter Linux 纹理 API 功能不全** — `FlutterDesktopTextureRegistrar` 可能只接受 `FlutterDesktopPixelBuffer`（CPU buffer），不支持外部 GPU 纹理 | 读 Flutter Linux embedding 源码 `flutter/engine/shell/platform/linux_embedder` + 写最小 demo 验证 | Phase 3 |
| 2 | **Linux DMA-BUF 在 NVIDIA 驱动下的兼容性** — EGL DMA-BUF import 直到 545 驱动才稳定 | 在 Ubuntu 24.04 + NVIDIA 545+ 上测试 DMA-BUF path | Phase 3 |
| 3 | **Windows Shared NTHANDLE 跨进程实际行为** — `CreateSharedHandle` 的 handle 能否直接传给另一个进程的 `OpenSharedResource` | 写最小 demo: 进程 A 创建 shareable texture → 进程 B OpenSharedResource → 验证纹理内容 | Phase 2 |

### 🟡 可延后验证

| # | 风险 | 验证方法 |
|---|------|---------|
| 4 | **Impeller Vulkan 后端纹理格式** — Vulkan 后端可能需要不同纹理格式 | Flutter 版本升级时验证 |
| 5 | **macOS ARM64 OpenGL 性能衰减** — Metal 翻译层可能有额外开销 | 做 fps benchmark 对比 |
| 6 | **Windows ARM64 Flutter 支持** — Snapdragon X 设备上 Flutter 是否稳定 | 有硬件时测试 |

### macOS OpenGL 废弃时间线

Apple 已在 macOS 15 标记 OpenGL deprecated。当前代码能跑，但应在设计里预留 Metal 路径：

```objc
// renderer_macos.mm 顶部
#ifndef USE_METAL
#define USE_METAL 0  // 默认 CGL, 编译时 -DUSE_METAL=1 切换
#endif

#if USE_METAL
// Metal 渲染路径 (骨架, 未来实现)
class MetalRenderer : public IRenderer { ... };
#else
// CGL 渲染路径 (当前)
class CGLRenderer : public IRenderer { ... };
#endif
```

---

## 10. 分阶段实施

### Phase 1: 重构 main.cpp (macOS, 已有功能不变)

- 抽离 `IRenderer` 接口 + `RendererConfig`
- 把当前 CGL 代码从 `main.cpp` 移到 `renderer_macos.mm`
- `main.cpp` 只保留 Camera, arcball, JSON, 顶点数据, main loop
- 验证 macOS x86_64 + arm64 都能编译运行

**产出**: `main.cpp`, `renderer.h`, `renderer_macos.mm`, `CMakeLists.txt`

### Phase 2: Windows D3D11

- 新建 `renderer_windows.cpp` (D3D11 渲染器)
- 新建 `windows/runner/zero_copy_plugin.cpp/.h` (Windows Plugin)
- 更新 `windows/CMakeLists.txt`
- Dart 端添加平台路径分派
- 跨进程共享纹理 demo 验证
- 构建脚本支持 x64 + ARM64

### Phase 3: Linux EGL

- 🔬 先验证 `FlutterDesktopTextureRegistrar` 功能
- 🔬 先验证 DMA-BUF 在目标环境下可用
- 新建 `renderer_linux.cpp` (EGL DMA-BUF + CPU fallback)
- 新建 `linux/runner/zero_copy_plugin.cc/.h` (Linux Plugin)
- 更新 `linux/CMakeLists.txt`
- CPU fallback 路径实现

### Phase 4: 完善 & 文档

- macOS Metal 路径骨架
- 纹理格式端到端验证
- 跨平台构建脚本 (`build_cube_renderer.sh`)
- 更新 README, IMPLEMENTATION.md
- 多表面（multi-surface）管理统一

---

## 11. 对抗审查记录

**Round 1 发现的问题 & 修正**:

| # | 问题 | 修正 |
|---|------|------|
| 1 | macOS ARM64 无原生 OpenGL 驱动 | 预留 `USE_METAL` 编译开关 |
| 2 | 遗漏 Windows ARM64 | CMake 支持 ARM64 生成器 |
| 3 | 遗漏 Linux 平台 | 新增 `renderer_linux.cpp` + CPU fallback |
| 4 | 构建系统单架构假设 | Universal binary + 多架构 CMake |
| 5 | Dart 端硬编码路径 | 平台感知 `_rendererPath()` |
| 6 | Flutter Plugin 每平台 API 不同 | 各平台独立 plugin 文件 |

**Round 2 发现的问题 & 修正**:

| # | 问题 | 修正 |
|---|------|------|
| 1 | Linux DMA-BUF 在 X11/NVIDIA 不可用 | CPU fallback 路径 + WARNING 日志 |
| 2 | Flutter Linux 纹理 API 功能未验证 | 标记为 🔬 事前验证任务 |
| 3 | Shared Handle vs NTHANDLE 版本陷阱 | 统一用 `SHARED_NTHANDLE` (Win8+) |
| 4 | macOS OpenGL 废弃 | Metal 路径骨架 + `USE_METAL` 开关 |
| 5 | 纹理格式不匹配导致隐式拷贝 | 格式矩阵 + 编译期/运行时检查 |
| 6 | Windows 控制台窗口泄漏 | `WIN32_EXECUTABLE TRUE` |
| 7 | 缺少多 surface 管理 | 每平台 plugin 用 `unordered_map<int64_t, Surface>` |
| 8 | HLSL shader 无编译步骤 | `shaders/` 目录 + 说明文档 |
| 9 | Impeller Vulkan 后端纹理格式未知 | 延后验证 |
| 10 | Flutter Linux 纹理 API 功能不全风险 | Phase 3 事前验证 |

---

## 附录: 文件变更总览

| 操作 | 文件 | 平台 |
|------|------|------|
| **重构** | `cube_renderer/main.cpp` | 全部 (抽离平台代码) |
| **新建** | `cube_renderer/renderer.h` | 全部 (接口定义) |
| **新建** | `cube_renderer/renderer_utils.h` | 全部 (共享工具) |
| **新建** | `cube_renderer/renderer_macos.mm` | macOS |
| **新建** | `cube_renderer/renderer_windows.cpp` | Windows |
| **新建** | `cube_renderer/renderer_linux.cpp` | Linux |
| **新建** | `cube_renderer/shaders/cube.vert` | macOS/Linux |
| **新建** | `cube_renderer/shaders/cube.frag` | macOS/Linux |
| **新建** | `cube_renderer/shaders/cube.hlsl` | Windows |
| **修改** | `cube_renderer/CMakeLists.txt` | 全部 |
| **新建** | `windows/runner/zero_copy_plugin.cpp` | Windows |
| **新建** | `windows/runner/zero_copy_plugin.h` | Windows |
| **修改** | `windows/CMakeLists.txt` | Windows |
| **新建** | `linux/runner/zero_copy_plugin.cc` | Linux |
| **新建** | `linux/runner/zero_copy_plugin.h` | Linux |
| **修改** | `linux/CMakeLists.txt` | Linux |
| **修改** | `lib/main.dart` | 全部 (平台路径分派) |
| **不变** | `macos/Runner/ZeroCopyTexturePlugin.swift` | macOS |
| **修改** | `README.md` | 全部 |
