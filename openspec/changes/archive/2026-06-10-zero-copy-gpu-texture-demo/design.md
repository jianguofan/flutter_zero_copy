## Context

Flutter macOS 应用的 3D 渲染需要高性能纹理共享。现有方案（NSOpenGLView 并列窗口）虽然性能好，但不支持在 3D 内容上叠加 Flutter widget。需要一种方案同时满足：60fps 性能、进程隔离、widget tree 嵌入、Flutter overlay。

参考文档 `docs/zero-copy-gpu-texture-sharing.md` 详细分析了四种方案，其中方案 C（Texture widget + GPU 纹理共享）是实现目标的最佳路径。

## Goals / Non-Goals

**Goals:**
- 实现 Flutter Texture widget 通过 IOSurface 零拷贝显示 C++ OpenGL 子进程的渲染输出
- C++ 子进程通过 `Process.run` 独立运行（进程隔离）
- Widget 支持可配置的 width/height/left/top 参数
- 最小 demo：旋转彩色立方体，验证零拷贝路径可达 60fps

**Non-Goals:**
- 跨平台支持（仅 macOS）
- 动态 resize（固定尺寸创建）
- IPC 帧同步（使用定时轮询）
- 复杂 3D 场景（仅单个立方体）
- 生产级错误处理

## Decisions

| 决策 | 选择 | 替代方案 | 理由 |
|------|------|----------|------|
| GPU 共享原语 | IOSurface | D3D Shared Resource, DMA-BUF | macOS 专有 demo |
| 子进程启动 | `Process.run` (独立可执行文件) | FFI 动态库、嵌入 bundle | 进程隔离清晰，最简实现 |
| Native 桥接 | Flutter Plugin + MethodChannel | dart:ffi | TextureRegistry 仅 Plugin 可访问 |
| 帧同步 | Ticker 轮询 (`textureFrameAvailable`) | Unix Socket IPC, IOSurface seed poll | 最简实现；C++ 连续渲染，每帧内容都不同 |
| OpenGL 版本 | Core Profile 3.3 (VAO/VBO/Shader) | Legacy 固定管线, Metal | macOS 唯一推荐的 OpenGL 方式 |
| 纹理注册 | CVPixelBuffer (IOSurface-backed) | 裸 Metal 纹理 | Flutter TextureRegistry 的标准 API |
| IOSurface 跨进程 | `kIOSurfaceIsGlobal` + `IOSurfaceLookup` | Mach Port 传递 | 最简单（虽然已 deprecated 但仍有效） |

## Risks / Trade-offs

- **kIOSurfaceIsGlobal 已 deprecated**: macOS 可能在未来版本移除全局 IOSurface 支持 → 已预留 Mach Port 方案（`IOSurfaceCreateMachPort`）
- **仅 macOS 确认可工作**: Windows/Linux 路径未验证 → 范围限定 macOS demo
- **OpenGL 在 macOS 上已 deprecated**: Apple 推动 Metal → 长期考虑子进程改用 Metal
- **进程生命周期管理简单**: 子进程崩溃不会自动重启 → Demo 范围内可接受

## Architecture

```
┌── Flutter 主进程 ─────────────────────────────────┐
│  Dart: Texture widget ← TextureRegistry           │
│  Plugin (Swift): IOSurface → CVPixelBuffer → 注册  │
└──────────────────┬───────────────────────────────┘
                   │ surfaceID (32-bit, 命令行参数)
                   ▼
┌── C++ 子进程 ─────────────────────────────────────┐
│  IOSurfaceLookup(surfaceID) → GL texture → FBO   │
│  渲染循环: glClear → drawCube → glFlush           │
└───────────────────────────────────────────────────┘
                   ▲
        IOSurface GPU VRAM (单次分配, 零拷贝)
        Metal reads ← same memory → OpenGL writes
```

## File Structure

```
flutter_zero_copy/
├── lib/main.dart                          # Flutter App + ZeroCopyWidget
├── macos/Runner/
│   ├── ZeroCopyTexturePlugin.swift        # IOSurface + CVPixelBuffer + TextureRegistry
│   └── MainFlutterWindow.swift            # Plugin 注册
├── cube_renderer/
│   ├── main.cpp                           # Headless GL 旋转立方体
│   └── CMakeLists.txt                     # Core Profile 3.3 构建
└── build_cube_renderer.sh                 # 一键编译脚本
```
