# Flutter Zero-Copy GPU Texture Sharing

> 跨进程零拷贝 GPU 纹理共享 — macOS (已完成) + Windows + Linux

## 概述

本项目演示了如何让 C++ OpenGL/D3D11 渲染的 3D 内容（旋转立方体）以**零拷贝**的方式直接显示在 Flutter 窗口中 — 无需 CPU 回读、无需序列化、无需纹理上传。

### 平台支持

| 平台 | 状态 | 零拷贝机制 | 性能 |
|------|------|-----------|------|
| **macOS** | ✅ 已完成 | IOSurface (全局 ID) | 稳定 60fps |
| **Windows** | 🔶 Phase 0 验证 | Named Shared Resource | 待验证 |
| **Linux** | 🔶 Phase 0 验证 | fork+fd 继承 / CPU fallback | 待验证 |

### 技术架构

- **Flutter 端**: MethodChannel → 平台纹理创建 → Texture Widget
- **C++ 端**: Headless OpenGL/D3D11 → 共享纹理绑定 → FBO 渲染 → Flush
- **同步机制**: 平台帧定时器驱动纹理更新 (60fps 目标)
- **交互控制**: Dart GestureDetector → stdin JSON 命令 → C++ arcball 相机 (旋转/缩放/重置)

## 架构

```
 Flutter App (Dart)                     C++ Renderer
      │                                       │
      ├─ IOSurface.create() ──────────────────┤─ IOSurface.lookup()
      ├─ Texture(textureId)                    │─ FBO → surface
      │                                       │─ arcball camera
      │          ┌──────────────┐             │
      │ Gesture  │  IOSurface   │◄────────────┤
      │ ───────► │  GPU VRAM    │  glFlush    │
      │  stdin   │  (零拷贝)     │             │
      │  JSON    └──────┬───────┘             │
      │                 │                      │
      │          Metal 采样                   │
      │          Impeller 合成                │
      ▼                 ▼                      ▼
           屏幕帧缓冲 (60fps)
```

## 🚀 快速开始

### macOS (已完成 ✅)

**环境要求**:
- macOS 12+ (Intel 或 Apple Silicon)
- Flutter 3.24+
- Xcode Command Line Tools
- CMake 3.16+

**运行**:
```bash
# 1. 编译 C++ 渲染器
bash build_cube_renderer.sh

# 2. 运行 Flutter 应用
flutter run -d macos
```

**发布模式**:
```bash
bash build_cube_renderer.sh
flutter build macos --release
cp cube_renderer/build/cube_renderer \
   build/macos/Build/Products/Release/flutter_zero_copy.app/Contents/MacOS/
open build/macos/Build/Products/Release/flutter_zero_copy.app
```

---

### Windows / Linux (Phase 0 验证 🔶)

**当前阶段**: 技术可行性验证

**下一步**:
```bash
# 查看完整文档索引
cat INDEX.md

# 运行验证 (自动检测系统)
./validate.sh

# 或手动验证
cd phase0_validation
cat QUICKSTART.md  # 阅读快速启动指南
```

**验证成功后**: 进入 Phase 2 (Windows) 或 Phase 3 (Linux) 实施

详见: [`phase0_validation/QUICKSTART.md`](phase0_validation/QUICKSTART.md)

## 📁 项目结构

```
flutter_zero_copy/
├── lib/
│   └── main.dart                         # Flutter 应用 (ZeroCopyWidget + Demo UI)
├── macos/
│   └── Runner/
│       └── ZeroCopyTexturePlugin.swift   # macOS 插件 (IOSurface + CVPixelBuffer) ✅
├── windows/                               # Windows 插件 (待实施)
├── linux/                                 # Linux 插件 (待实施)
├── cube_renderer/
│   ├── main.cpp                          # C++ 渲染器 (macOS 已完成) ✅
│   ├── renderer_windows.cpp              # Windows 渲染器 (待实施)
│   ├── renderer_linux.cpp                # Linux 渲染器 (待实施)
│   └── CMakeLists.txt                    # 跨平台构建配置
│
├── phase0_validation/                    # Phase 0: 技术验证 🔶
│   ├── README.md                         # 验证总体介绍
│   ├── QUICKSTART.md                     # 快速启动指南 ⭐
│   ├── SUMMARY.md                        # 验证结果记录 (待填写)
│   ├── demo_windows_named_handle/        # Windows 验证 demo
│   │   ├── README.md
│   │   ├── parent.cpp
│   │   ├── child.cpp
│   │   └── build.bat
│   └── demo_linux_fork_fd/               # Linux 验证 demo
│       ├── README.md
│       ├── demo_linux_fork_fd.c
│       └── build.sh
│
├── docs/
│   ├── IMPLEMENTATION.md                 # macOS 实现文档
│   ├── ZERO_COPY_PRINCIPLES.md           # 零拷贝原理
│   └── superpowers/specs/
│       └── 2026-06-11-cross-platform-windows-linux-design.md  # 跨平台设计
│
├── INDEX.md                              # 📖 文档索引 (从这里开始)
├── WORK_SUMMARY.md                       # 🎯 工作总结 (对抗审查结果)
├── ROADMAP.md                            # 🗺️ 实施路线图 (9-17 天)
├── validate.sh                           # ⚡ 验证执行脚本
├── build_cube_renderer.sh                # 构建脚本 (macOS)
└── .vscode/
    ├── launch.json                       # VS Code 调试配置
    └── tasks.json                        # VS Code 构建 task
```

## 文档

| 文档 | 内容 |
|------|------|
| [`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md) | 系统架构、文件详解、API 映射、调试指南、Bug 记录 |
| [`docs/ZERO_COPY_PRINCIPLES.md`](docs/ZERO_COPY_PRINCIPLES.md) | 零拷贝原理、内存模型、时序图、常见误区、跨平台对应概念 |

## 交互控制协议

Flutter 手势 → C++ stdin JSON 命令：

| 手势 | JSON 命令 |
|------|----------|
| 拖拽 | `{"type":"rotate","dx":12.0,"dy":5.0}` |
| 滚轮/捏合 | `{"type":"zoom","scale":1.5}` |
| 双击 | `{"type":"reset"}` |
| 配置 | `{"type":"config","autoRotate":false}` |

## 性能

| 方案 | 每帧延迟 | 60fps 可行性 |
|------|---------|-------------|
| 传统 (glReadPixels + CPU 拷贝) | 8–15ms | ❌ 15–25fps |
| **零拷贝 (IOSurface)** | **<0.1ms** | ✅ 稳定 60fps |

## 调试

C++ 端 stdout 默认全缓冲（pipe 模式），已通过 `setvbuf(stdout, NULL, _IONBF, 0)` 禁用。
控制台日志格式：

```
[cube] [cube_renderer] INITIAL STATE: autoRotate=0, zoom=6.00
[cube] [cube_renderer] stdin: read 45 bytes, buf len=45
[cube] [cube_renderer] stdin: processing line: {"type":"rotate","dx":22.3,"dy":2.7}
[cube] [cube_renderer] rotate dx=22.33 dy=2.15
```

## 许可

Internal project — Snapmaker.
