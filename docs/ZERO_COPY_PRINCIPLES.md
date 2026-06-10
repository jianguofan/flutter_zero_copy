# 零拷贝 GPU 纹理共享 — 原理篇

> 从 IOSurface 到 Flutter 画布，逐层拆解数据如何"不拷贝"地从 C++ OpenGL 渲染直接显示在 Flutter 窗口中。

---

## 目录

1. [核心直觉：同一张纸](#1-核心直觉同一张纸)
2. [CVPixelBuffer 到底是什么](#2-cvpixelbuffer-到底是什么)
3. [IOSurface 内存布局](#3-iosurface-内存布局)
4. [Flutter 如何将 IOSurface 画到屏幕上](#4-flutter-如何将-iosurface-画到屏幕上)
5. [为什么这是零拷贝](#5-为什么这是零拷贝)
6. [完整链路时序图](#6-完整链路时序图)
7. [常见误区](#7-常见误区)
8. [跨平台对应概念](#8-跨平台对应概念)

---

## 1. 核心直觉：同一张纸

### 1.1 一句话类比

> C++ 在一张纸上画立方体，Flutter 把**同一张纸**贴在自己的窗口里展示。从头到尾只有一张纸。没有复印，没有拍照，没有搬运。

### 1.2 三个精度递增的类比

| 类比 | 对应操作 | 有无拷贝 |
|------|----------|----------|
| 🎥 **摄像头** | C++ 画 → 摄像头拍 → 生成新影像 → Flutter 播 | ❌ 光学采样 = 拷贝 |
| 🪟 **窗户** | 窗外的人在画画，你透过玻璃直接看 | ✅ 无拷贝 |
| 🖼️ **同一张纸** | C++ 在纸上画，Flutter 把**这张纸本身**贴在窗口里 | ✅✅ 最精确 |

### 1.3 类比与代码的对应

```
C++ 的操作:
  IOSurfaceLookup(surfaceID)   →  找到那张纸
  glBindFramebuffer(surface)   →  把画架支在纸前面
  drawRotatingCube()           →  落笔画画
  glFlush()                    →  搁笔，确保颜料在纸上

Flutter 的操作:
  copyPixelBuffer()            →  把纸拿过来 (拿的是纸本身，不是复印件)
  CVPixelBufferGetIOSurface()  →  确认这就是那张纸
  newTextureWithIOSurface()    →  把纸贴在展示框里
  GPU textureSample()          →  大家现在能看到了
```

---

## 2. CVPixelBuffer 到底是什么

### 2.1 它不是"装满 RGBA 的大数组"

CVPixelBuffer 是一个**容器 / 描述符**，包含两部分：

```
CVPixelBuffer 结构:
┌─────────────────────────────────────────────────┐
│  元数据 (Metadata)                               │
│  ├─ width: 600                                  │
│  ├─ height: 450                                 │
│  ├─ pixelFormat: kCVPixelFormatType_32BGRA       │
│  ├─ bytesPerRow: 2400  (600 × 4)                │
│  └─ 锁状态 / 引用计数 / 时间戳 等                 │
│                                                  │
│  存储后端 (Backing Store) — 数据真正存放的位置     │
│  └─ 指向实际像素数据的引用                        │
│     可以是:                                      │
│     ✅ IOSurface (GPU 显存) ← 本项目使用          │
│     ✅ malloc 的堆内存 (CPU RAM)                  │
│     ✅ VRAM 的其他区域                            │
│     ✅ 其他进程的内存 (通过 Mach 端口共享)          │
└─────────────────────────────────────────────────┘
```

**关键区分**：CVPixelBuffer 本身**不拥有数据**。它只是一个指向数据的"视图"。数据实际存在哪里，由创建时指定的 backing store 决定。

### 2.2 本项目中 CVPixelBuffer 与 IOSurface 的关系

```swift
// 数据实体：GPU 显存中的一块区域
let surface = IOSurfaceCreate(props)  // ← 这才是真正的像素数据所在

// 视图：指向上面那块显存的 CVPixelBuffer
CVPixelBufferCreateWithIOSurface(..., surface, ..., &pixelBuffer)
//                               ↑
//   pixelBuffer 不拷贝 surface 的数据
//   它只是记录了: "数据在 surface 里，格式是 BGRA，尺寸是 600×450"
```

用代码验证这一点：

```swift
// 验证 CVPixelBuffer 底层确实是 IOSurface
let ioSurface = CVPixelBufferGetIOSurface(pixelBuffer)
// ioSurface == surface  → 同一个对象，同一块内存

// 验证两个进程看到的数据是一致的
IOSurfaceLock(surface, .readOnly, nil)
let ptr = IOSurfaceGetBaseAddress(surface)
let pixel0 = ptr.bindMemory(to: UInt32.self, capacity: 1)[0]
// pixel0 == 0xFF00FFFF  → 品红色，和 C++ 写入的一致
IOSurfaceUnlock(surface, .readOnly, nil)
```

---

## 3. IOSurface 内存布局

### 3.1 物理存储格式

IOSurface 内部存储的是**每像素 4 字节的 BGRA 数据**（在 Apple Silicon 上是原生格式）：

```
IOSurface 内存布局 (width=4, height=3 示意):

列号:    0        1        2        3
行0:  [B G R A][B G R A][B G R A][B G R A]
行1:  [B G R A][B G R A][B G R A][B G R A]
行2:  [B G R A][B G R A][B G R A][B G R A]

物理上是一块连续内存:
  偏移 0:      行0-像素0-B, 行0-像素0-G, 行0-像素0-R, 行0-像素0-A
  偏移 4:      行0-像素1-B, ...
  ...
  偏移 2400:   行1-像素0  (跳过行0末尾的对齐填充)
  ...

总大小 = height × bytesPerRow = 450 × 2400 = 1,080,000 字节 ≈ 1.03 MB
```

### 3.2 CPU 直接访问

```swift
IOSurfaceLock(surface, [], nil)
let base = IOSurfaceGetBaseAddress(surface)
let ptr = base.bindMemory(to: UInt32.self, capacity: width * height)

// 读/写像素就像操作普通数组
ptr[0]           = 0xFF00FFFF   // 像素0: B=FF, G=00, R=FF, A=FF → 品红
ptr[1]           = 0xFFFF0000   // 像素1: B=FF, G=FF, R=00, A=00 → 亮蓝
let centerPixel  = ptr[225 * width + 300]  // 读中心像素

IOSurfaceUnlock(surface, [], nil)
```

### 3.3 IOSurface 的核心能力

| 能力 | 说明 | 在本项目中的用途 |
|------|------|-----------------|
| **跨进程共享** | 通过 `surfaceID` (uint32) 让不同进程访问同一块 GPU 内存 | Dart 进程创建 → C++ 进程查找并渲染 |
| **CPU 直接访问** | `IOSurfaceGetBaseAddress()` 返回内存指针 | 填充测试像素验证管线 |
| **GPU 纹理绑定** | Metal / OpenGL 可直接绑定为纹理 | C++ OpenGL FBO 渲染目标；Flutter Metal 采样源 |
| **Core Video 包装** | `CVPixelBufferCreateWithIOSurface()` 零拷贝包装 | 连接 Flutter TextureRegistry |
| **Core Image 集成** | `CIImage(ioSurface:)` 直接创建 | 可对表面应用滤镜 |
| **同步机制** | `IOSurfaceGetSeed()` 读写锁 | 检测是否有新帧 |

---

## 4. Flutter 如何将 IOSurface 画到屏幕上

### 4.1 不是"把 RGBA 数据拷过去画"

这是最容易产生的误解。Flutter **不是**这样做的：

```
❌ 错误理解:
   IOSurface → CPU 读取 RGBA 字节 → 复制到 Dart Uint8List
   → Canvas.drawImage() → 软件绘制像素到屏幕
```

而是这样：

```
✅ 实际流程:
   IOSurface → 提取 → GPU 纹理引用 → GPU 采样 → 屏幕
```

### 4.2 逐层拆解

#### 第一层：Native Plugin — 注册纹理源

```swift
// ZeroCopyTexturePlugin 实现 FlutterTexture 协议
class ZeroCopyTexturePlugin: NSObject, FlutterPlugin, FlutterTexture {

    // 向 Flutter 引擎注册自己，获得 textureId
    textureId = textureRegistry!.register(self)
    // 引擎持有 self 的引用，记录在纹理表中

    // 当引擎需要像素数据时回调此方法
    func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        // 直接返回已有的 CVPixelBuffer（底层是 IOSurface）
        // ⚠️ 没有拷贝 — 引用计数 +1 而已
        return Unmanaged.passRetained(pixelBuffer)
    }
}
```

#### 第二层：Dart — Texture Widget

```dart
// textureId 通过 MethodChannel 从 Native 获取
final textureId = result['textureId'] as int;  // 例如 40791579776

// 这是 Flutter 框架内置的 Widget
Texture(textureId: textureId)
```

`Texture` widget 不是自定义组件。它是 Flutter 框架提供的原生平台纹理显示组件。当它被挂载到 Widget Tree 后，创建 `RenderTexture` 这个 RenderObject。

#### 第三层：Flutter Engine (C++) — 合成管线

这是最核心的部分，发生在 Flutter 引擎内部：

```
RenderTexture.paint()
  → 向 SceneBuilder 添加一个 "ExternalTexture" 层
  → 层信息: {textureId: 42, rect: (30, 80, 630, 530)}
  → 传递给引擎 C++ 层
```

```cpp
// Flutter 引擎 C++ 代码 (简化版)

// 步骤 1: 从纹理表中查找
auto* texture = texture_registry_->GetTexture(texture_id);
// texture 就是 ZeroCopyTexturePlugin 实例

// 步骤 2: 获取像素缓冲
auto pixelBuffer = texture->copyPixelBuffer();
// 调用的是 Swift 实现的 copyPixelBuffer()
// 返回 CVPixelBuffer（底层是 IOSurface）

// 步骤 3: 提取 IOSurface
IOSurfaceRef ioSurface = CVPixelBufferGetIOSurface(pixelBuffer);

// 步骤 4: 创建 GPU 纹理 (Metal 后端)
id<MTLTexture> gpuTexture = [device newTextureWithDescriptor:desc
                                                   iosurface:ioSurface
                                                       plane:0];
// ⚠️ gpuTexture 指向的物理内存 = IOSurface 的物理内存
// 没有拷贝！只是创建了一个 GPU 侧的"引用"

// 步骤 5: GPU 合成 — 片段着色器采样
// 对屏幕矩形内的每个像素:
//   color = gpuTexture.sample(texCoord)
//   framebuffer[pixel] = color
// 这是 GPU 硬件操作，读取的是显存中的数据
```

### 4.3 关键点总结

整个链路中，RGBA 字节**从未经过 CPU**。数据始终停留在 GPU 显存中：

```
IOSurface (GPU VRAM)
     │
     ├── C++ OpenGL: glBindFramebuffer → 写入像素 (GPU 操作)
     │
     └── Flutter Metal: newTextureWithIOSurface → 采样像素 (GPU 操作)
                                                         │
                                                   屏幕帧缓冲
```

---

## 5. 为什么这是零拷贝

### 5.1 传统方案 vs 零拷贝方案

```
传统方案 (PlatformView / CPU readback):
═══════════════════════════════════════════════════
  ① glReadPixels():        GPU → CPU 拷贝 (2-4ms)
  ② IPC 序列化/反序列化:     CPU 数据打包/解包 (1-2ms)
  ③ decodeImageFromPixels: CPU → GPU 上传 (2-4ms)
  ─────────────────────────────────────────
  总计: 8-15ms
  帧预算 16.6ms (60fps) → 只剩 1-8ms → 实际 FPS: 15-25


零拷贝方案 (IOSurface):
═══════════════════════════════════════════════════
  ① glFlush():             GPU 内部刷新 (<0.01ms)
  ② CVDisplayLink 回调:    标记纹理已更新 (<0.1ms)
  ③ GPU 采样 IOSurface:   0ms — 本就是 GPU 采样
  ─────────────────────────────────────────
  总计: <0.1ms
  帧预算剩余 16.5ms → 稳定 60fps
```

### 5.2 两种方案的图示

```
传统方案 (有拷贝):

  [IOSurface GPU显存]                [Flutter Canvas]
  ┌─────────────────┐                ┌─────────────────┐
  │ B G R A B G R A │  ─CPU拷贝─→   │  CPU 内存中的   │
  │ B G R A B G R A │   glReadPixels │  Uint8List      │
  │       ...       │     慢!        │       │         │
  └─────────────────┘                │  GPU上传(又慢!) │
                                     │       ↓         │
                                     │  GPU Texture    │
                                     │       ↓         │
                                     │  采样→屏幕      │
                                     └─────────────────┘


零拷贝方案 (本项目):

  [IOSurface GPU显存]                [Flutter Canvas]
  ┌─────────────────┐                ┌─────────────────┐
  │ B G R A B G R A │                │                 │
  │ B G R A B G R A │ ← 同一个指针 ─→│  GPU Texture    │
  │       ...       │   MTLTexture   │       ↓         │
  └─────────────────┘                │  采样→屏幕      │
        ▲                            └─────────────────┘
        │ 同时写入
  ┌─────┴───────────┐
  │ C++ OpenGL FBO  │  直接渲染到同一块显存
  └─────────────────┘
```

### 5.3 "零拷贝"的严格定义

| 阶段 | 传统方案 | 本项目 |
|------|---------|--------|
| **像素数据位置** | GPU VRAM | GPU VRAM |
| **数据流向** | GPU→CPU→GPU (两次跨总线拷贝) | 始终在 GPU |
| **内存份数** | 至少 3 份 (VRAM, CPU RAM, 新 VRAM) | 1 份 |
| **总线带宽占用** | 每帧 2×RGBA 数据量 | 0 |

---

## 6. 完整链路时序图

```
时间 →

Native Plugin          Flutter Engine            Dart/Widget           C++ Renderer
     │                       │                       │                      │
     │─ createSurface() ────>│                       │                      │
     │  IOSurfaceCreate      │                       │                      │
     │  CVPixelBufferCreate  │                       │                      │
     │  textureRegistry      │                       │                      │
     │    .register(self)───>│ 存入纹理表              │                      │
     │  <- textureId ────────│                       │                      │
     │                       │                       │                      │
     │────── surfaceID, textureId ──────────────────>│                      │
     │                       │                       │ 启动 C++ 进程 ─────>│
     │                       │                       │ surfaceID 传入       │
     │                       │                       │                      │ IOSurfaceLookup()
     │                       │                       │                      │ 绑定为 GL FBO
     │                       │                       │                      │
     │                       │                       │ Widget build:        │
     │                       │                       │ Texture(textureId)   │
     │                       │<── 创建 RenderTexture │                      │
     │                       │                       │                      │
     │                       │═══ VSync 信号 ═══════>│                      │
     │<─ CVDisplayLink 回调  │                       │                      │
     │  textureFrameAvail()─>│ 标记纹理已更新         │                      │
     │                       │                       │                      │
     │                       │─── Layout/Paint ─────>│                      │
     │                       │                       │                      │
     │<─ copyPixelBuffer() ──│                       │                      │
     │  返回 CVPixelBuffer   │                       │                      │
     │                       │ CVPixelBuffer         │                      │
     │                       │   → CVPixelBufferGetIOSurface()             │
     │                       │   → newTextureWithIOSurface()               │
     │                       │   → GPU 采样 → 合成到帧缓冲                 │
     │                       │                       │                      │
     │                       │                       │             同时 ───>│
     │                       │                       │             glClear  │
     │                       │                       │             glDraw*  │
     │                       │                       │             glFlush │
     │                       │                       │                      │
     │                       │═══ 下一帧 VSync ═════>│                      │
     │  textureFrameAvail()  │                       │                      │
     │  copyPixelBuffer()    │  ← 同一块 IOSurface，已有新帧内容            │
     │  GPU 重新采样         │                       │                      │
```

---

## 7. 常见误区

### 误区 1：CVPixelBuffer 就是像素数组

**真相**：CVPixelBuffer 是容器/视图，像素数据存储在其 backing store（本项目是 IOSurface GPU 显存）中。

### 误区 2：Flutter 把 CVPixelBuffer 的 RGBA 数据复制到 Dart 再画

**真相**：Flutter 从 CVPixelBuffer 中提取 IOSurface，直接在 GPU 上创建纹理引用，无需任何 CPU 拷贝。

### 误区 3：copyPixelBuffer() 名字里的 "copy" 意味着有拷贝

**真相**：`copyPixelBuffer()` 是 Flutter 引擎定义的协议方法名。这里返回时只是 `Unmanaged.passRetained(pixelBuffer)` — 引用计数 +1，不是 memcpy。

### 误区 4：Texture Widget 和普通 Image Widget 工作原理一样

**真相**：`Image` widget 使用 `dart:ui Image`（像素数据在 Dart 堆或 GPU 纹理中）。`Texture` widget 则是外部纹理引用 — 像素数据由 Native 代码管理，引擎只负责采样。

### 误区 5：两个进程同时读写 IOSurface 需要加锁

**半对**：只有 CPU 访问时需要 `IOSurfaceLock/Unlock`。GPU 操作（Metal 采样 + OpenGL 渲染）由 GPU 硬件保证顺序一致性 — `glFlush()` 之后的所有读取者都能看到最新内容。

---

## 8. 跨平台对应概念

| 概念 | macOS | Windows | Linux |
|------|-------|---------|-------|
| **共享 GPU 内存** | `IOSurface` | D3D11 Shared Resource / D3D12 Shared Heap | DMA-BUF |
| **跨进程句柄** | `surfaceID` (uint32) | NT Handle (`HANDLE`) | file descriptor (int) |
| **句柄传递方式** | 命令行参数 / XPC | `DuplicateHandle` / `OpenSharedResource` | `SCM_RIGHTS` (Unix Socket) |
| **像素缓冲包装** | `CVPixelBuffer` / `CVPixelBufferCreateWithIOSurface` | `ID3D11Texture2D` + `D3D11_RESOURCE_MISC_SHARED` | `gbm_bo` / `EGLImage` |
| **Flutter GPU 后端** | Metal (Impeller) | D3D11 / Vulkan | Vulkan |
| **外部渲染 API** | OpenGL / Metal | OpenGL / D3D11 | OpenGL / Vulkan |
| **VSync 驱动** | `CVDisplayLink` | `D3DKMTWaitForVerticalBlank` / `IDXGIOutput::WaitForVBlank` | `drmWaitVBlank` |

---

## 参考

- [Apple IOSurface Documentation](https://developer.apple.com/documentation/iosurface)
- [Apple CVPixelBuffer Documentation](https://developer.apple.com/documentation/corevideo/cvpixelbuffer)
- [CGLTexImageIOSurface2D](https://developer.apple.com/documentation/opengl/1506112-cglteximageiosurface2d)
- [Flutter Texture Widget](https://api.flutter.dev/flutter/widgets/Texture-class.html)
- [Flutter External Textures (macOS)](https://docs.flutter.dev/platform-integration/macos/texture-sharing)
- [Metal Texture Creation from IOSurface](https://developer.apple.com/documentation/metal/mtldevice/1433378-newtexturewithdescriptor)
- 项目实现文档: [`IMPLEMENTATION.md`](./IMPLEMENTATION.md)
