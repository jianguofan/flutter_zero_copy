# Flutter Zero-Copy GPU Texture Sharing

> 基于 macOS IOSurface 的跨进程零拷贝 GPU 纹理共享演示

## 概述

本项目演示了如何让 C++ OpenGL 渲染的 3D 内容（旋转立方体）以**零拷贝**的方式直接显示在 Flutter 窗口中 — 无需 CPU 回读、无需序列化、无需纹理上传。

- **Flutter 端**: MethodChannel → IOSurface 创建 → CVPixelBuffer → Texture Widget
- **C++ 端**: Headless OpenGL → IOSurface 绑定 → FBO 渲染 → glFlush
- **同步机制**: CVDisplayLink 硬件 VSync 回调驱动帧更新 (60fps)

## 架构

```
Flutter App (Dart)                  C++ Renderer
     │                                    │
     ├─ IOSurface.create() ───────────────┤─ IOSurface.lookup()
     ├─ Texture(textureId)                 │─ FBO → surface
     │                                    │─ drawRotatingCube()
     │         ┌──────────────┐           │
     │         │  IOSurface   │◄──────────┤
     │         │  GPU VRAM    │  glFlush  │
     │         │  (零拷贝)     │           │
     │         └──────┬───────┘           │
     │                │                    │
     │         Metal 采样                 │
     │         Impeller 合成              │
     ▼                                    ▼
          屏幕帧缓冲 (60fps)
```

## 快速开始

### 环境要求

- macOS 15+ (Apple Silicon)
- Flutter 3.24+
- Xcode 26+ (Command Line Tools)
- CMake 3.16+

### 构建与运行

```bash
# 1. 编译 C++ 渲染器
bash build_cube_renderer.sh

# 2. 运行 Flutter 应用
fvm flutter run -d macos
```

### 发布模式

```bash
bash build_cube_renderer.sh
fvm flutter build macos --release
cp cube_renderer/build/cube_renderer \
   build/macos/Build/Products/Release/flutter_zero_copy.app/Contents/MacOS/
open build/macos/Build/Products/Release/flutter_zero_copy.app
```

## 项目结构

```
flutter_zero_copy/
├── lib/
│   └── main.dart                    # Flutter 应用 (ZeroCopyWidget + Demo UI)
├── macos/
│   └── Runner/
│       └── ZeroCopyTexturePlugin.swift  # Native 插件 (IOSurface + CVPixelBuffer)
├── cube_renderer/
│   ├── main.cpp                     # C++ OpenGL 渲染器 (headless, 旋转立方体)
│   └── CMakeLists.txt               # C++ 构建配置
├── build_cube_renderer.sh           # 一键编译脚本
├── docs/
│   ├── IMPLEMENTATION.md            # 实现文档 (系统架构、API 映射、调试指南)
│   └── ZERO_COPY_PRINCIPLES.md      # 原理文档 (内存模型、时序图、常见误区)
└── .vscode/
    ├── launch.json                  # VS Code 调试配置 (含 C++ 预编译 task)
    └── tasks.json                   # VS Code 构建 task
```

## 文档

| 文档 | 内容 |
|------|------|
| [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) | 系统架构、文件详解、API 映射、调试指南、Bug 记录 |
| [`docs/ZERO_COPY_PRINCIPLES.md`](docs/ZERO_COPY_PRINCIPLES.md) | 零拷贝原理、内存模型、时序图、常见误区、跨平台对应概念 |

## 性能

| 方案 | 每帧延迟 | 60fps 可行性 |
|------|---------|-------------|
| 传统 (glReadPixels + CPU 拷贝) | 8–15ms | ❌ 15–25fps |
| **零拷贝 (IOSurface)** | **<0.1ms** | ✅ 稳定 60fps |

## 许可

Internal project — Snapmaker.
