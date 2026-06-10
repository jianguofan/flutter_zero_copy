## Why

Flutter 应用需要在 widget tree 中嵌入 3D 渲染内容（由 C++ OpenGL 子进程渲染），并达到 60fps 性能。传统方案（PlatformView、CPU readback）引入 8-15ms 的 GPU↔CPU 像素拷贝延迟，无法满足实时渲染需求。需要验证 macOS IOSurface 零拷贝 GPU 纹理共享方案作为最佳实践。

## What Changes

- 新增 `ZeroCopyWidget` — 一个可配置宽高位置的 Flutter widget，通过 Texture widget 显示由外部 C++ OpenGL 进程渲染的 3D 内容
- 新增 macOS Flutter Plugin — 创建 IOSurface → CVPixelBuffer → Metal 纹理 → Flutter TextureRegistry，实现零拷贝纹理注册
- 新增独立 C++ 可执行文件 `cube_renderer` — Headless OpenGL (Core Profile 3.3) 渲染旋转立方体到共享 IOSurface，通过 `Process.run` 启动
- 零拷贝路径：主进程 Metal 纹理 和 C++ OpenGL FBO 共享同一块 IOSurface GPU VRAM，像素数据从未拷贝

## Capabilities

### New Capabilities

- `zero-copy-texture-widget`: Flutter Texture widget 通过 IOSurface 实现跨进程 GPU 零拷贝纹理共享，支持可配置的宽高和位置
- `cube-renderer-process`: Headless C++ OpenGL 子进程，通过 IOSurfaceLookup 绑定共享 GPU 内存并渲染旋转立方体

### Modified Capabilities

<!-- No existing capabilities modified -->

## Impact

- 新增文件: `lib/main.dart`, `macos/Runner/ZeroCopyTexturePlugin.swift`, `cube_renderer/main.cpp`, `cube_renderer/CMakeLists.txt`
- 修改文件: `macos/Runner/MainFlutterWindow.swift`（注册 Plugin）
- 新增依赖: IOSurface.framework, Metal.framework, CoreVideo.framework, OpenGL.framework
- 平台: 仅 macOS（计划后续扩展 Windows/Linux）
