# Flutter Zero-Copy GPU Texture Sharing + UI 迁移项目

> 跨进程零拷贝 GPU 纹理共享 + Snapmaker 设备控制 UI

---

## 🎯 项目概述

本项目包含两大部分：

### 1. 零拷贝 GPU 纹理共享（原有功能）
跨进程零拷贝 GPU 纹理共享 — macOS (已完成) + Windows + Linux

让 C++ OpenGL/D3D11 渲染的 3D 内容（旋转立方体）以**零拷贝**的方式直接显示在 Flutter 窗口中。

### 2. Snapmaker 设备控制 UI 迁移 ⭐ 新增
完整的设备控制界面，包括项目管理、设备控制、打印任务和耗材管理。

---

## ✅ UI 迁移完成状态

### 成果统计
- **组件数量**：16个组件
- **代码行数**：约1800行
- **测试状态**：✅ 编译通过，应用运行正常
- **UI还原度**：95%+

### 功能列表
1. ✅ 顶部导航栏（准备、预览、设备、项目）
2. ✅ 项目页面（4列网格布局）
3. ✅ 设备控制页面：
   - 摄像头视图
   - 温度监控（4个挤出头+热床+腔体）
   - XYZ轴控制
   - 打印任务管理
   - 耗材管理（4个耗材槽）

---

## 🚀 快速开始

### UI 演示模式
```bash
# 1. 安装依赖
flutter pub get

# 2. 运行应用（默认显示 UI 演示）
flutter run -d macos
```

**查看功能**：
- 点击顶部"项目"Tab：查看项目网格布局
- 点击顶部"设备"Tab：查看设备控制界面
  - 控制子Tab：摄像头+温度+XYZ控制
  - 打印任务子Tab：任务进度显示
  - 耗材子Tab：4个耗材槽管理

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
│   ├── main.dart                         # 应用入口
│   ├── widgets/                          # ⭐ 新增：共享组件
│   │   └── top_navigation_bar.dart
│   └── pages/                            # ⭐ 新增：页面
│       ├── main_frame_page.dart          # 主框架
│       ├── ui_demo_page.dart             # UI演示页面
│       ├── projects/                     # 项目管理
│       │   ├── projects_page.dart
│       │   └── widgets/
│       │       ├── project_card.dart
│       │       ├── project_grid.dart
│       │       └── project_header.dart
│       └── device/                       # 设备控制
│           ├── device_control_full_page.dart
│           └── widgets/
│               ├── device_selector.dart
│               ├── device_camera_view.dart
│               ├── device_control_left_panel.dart
│               ├── device_control_right_panel.dart
│               ├── device_print_task_view.dart
│               ├── device_filament_view.dart
│               ├── device_control_panel.dart
│               └── device_empty_state.dart
├── macos/
│   └── Runner/
│       └── ZeroCopyTexturePlugin.swift   # macOS 插件 (IOSurface) ✅
├── cube_renderer/
│   ├── main.cpp                          # C++ 渲染器 (macOS) ✅
│   └── CMakeLists.txt
│
├── docs/                                 # ⭐ 新增：UI 迁移文档
│   ├── UI_MIGRATION_COMPLETE.md          # 完成总结
│   ├── INTEGRATION_TEST_REPORT.md        # 集成测试报告
│   ├── DEVICE_CONTROL_MIGRATION.md       # 设备控制迁移
│   └── QUICKSTART.md                     # 快速开始
│
├── phase0_validation/                    # Phase 0: 技术验证 🔶
│   └── ...
└── ...
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
