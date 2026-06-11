# 项目文档索引

> 快速查找所有设计文档、验证 demo、实施计划

---

## 📚 核心文档

### 1. 工作总结 ⭐ 从这里开始
**文件**: [`WORK_SUMMARY.md`](WORK_SUMMARY.md)

**内容**: 完整的问题发现、修正设计、验证方案总结

**适合**: 了解整个项目的背景、问题和解决方案

---

### 2. 实施路线图
**文件**: [`ROADMAP.md`](ROADMAP.md)

**内容**: 分 4 个 Phase 的详细实施计划，预计 9-17 天完成

**适合**: 项目管理、时间估算、任务分配

---

### 3. 原始设计文档（有问题）
**文件**: [`docs/superpowers/specs/2026-06-11-cross-platform-windows-linux-design.md`](docs/superpowers/specs/2026-06-11-cross-platform-windows-linux-design.md)

**内容**: 原始的跨平台设计，包含 5 个阻塞性问题

**适合**: 了解问题来源，对比修正前后的差异

---

## 🧪 Phase 0: 技术验证

### 验证总体说明
**文件**: [`phase0_validation/README.md`](phase0_validation/README.md)

**内容**: Phase 0 的目标、验证项目、成功标准

---

### 快速启动指南 ⭐ 验证前必读
**文件**: [`phase0_validation/QUICKSTART.md`](phase0_validation/QUICKSTART.md)

**内容**: 30 秒快速开始，详细步骤，故障排除

**适合**: 第一次运行验证 demo

---

### 验证总结（待填写）
**文件**: [`phase0_validation/SUMMARY.md`](phase0_validation/SUMMARY.md)

**内容**: 验证结果记录表格，技术决策

**适合**: 验证完成后填写，作为 Phase 2/3 的依据

---

## 🪟 Windows 验证

### Windows Demo 说明
**文件**: [`phase0_validation/demo_windows_named_handle/README.md`](phase0_validation/demo_windows_named_handle/README.md)

**内容**: 
- Windows named shared resource 验证原理
- 构建步骤（Visual Studio）
- 运行方法
- 故障排除
- 技术细节

---

### Windows Demo 源码
**文件**: 
- [`phase0_validation/demo_windows_named_handle/parent.cpp`](phase0_validation/demo_windows_named_handle/parent.cpp)
- [`phase0_validation/demo_windows_named_handle/child.cpp`](phase0_validation/demo_windows_named_handle/child.cpp)
- [`phase0_validation/demo_windows_named_handle/build.bat`](phase0_validation/demo_windows_named_handle/build.bat)

**运行**:
```cmd
cd phase0_validation\demo_windows_named_handle
build.bat
cd build
parent.exe
```

---

## 🐧 Linux 验证

### Linux Demo 说明
**文件**: [`phase0_validation/demo_linux_fork_fd/README.md`](phase0_validation/demo_linux_fork_fd/README.md)

**内容**:
- Linux fork + DMA-BUF fd 继承验证原理
- 依赖安装（libgbm, EGL, DRM）
- 构建步骤（GCC）
- 运行方法
- 故障排除
- CPU fallback 替代方案

---

### Linux Demo 源码
**文件**:
- [`phase0_validation/demo_linux_fork_fd/demo_linux_fork_fd.c`](phase0_validation/demo_linux_fork_fd/demo_linux_fork_fd.c)
- [`phase0_validation/demo_linux_fork_fd/build.sh`](phase0_validation/demo_linux_fork_fd/build.sh)

**运行**:
```bash
cd phase0_validation/demo_linux_fork_fd
./build.sh
./demo_linux_fork_fd
```

---

## 📝 修正设计（推荐创建）

**建议**: 将修正后的设计写入独立文档

**文件**: `docs/superpowers/specs/2026-06-11-cross-platform-CORRECTED.md`

**内容**（基于对抗审查结果）:
- Windows 改用 Named Shared Resource
- Linux 提供 fork+fd 和 CPU fallback 双路径
- 所有平台使用 callback 机制
- 完整的生命周期管理
- 正确的纹理格式

**参考**: 本文档的 WORK_SUMMARY.md "修正后的架构" 章节

---

## 🔍 对抗审查报告

**来源**: Multi-agent workflow 审查结果

**内容**:
- API 可行性验证
- 句柄传递机制分析
- 纹理格式兼容性
- 生命周期管理审查
- 5 个阻塞性问题 + 6 个重要问题 + 9 个优化点

**位置**: 见 WORK_SUMMARY.md "原设计的关键问题" 章节

---

## 🎯 快速导航

### 我想...

#### → 了解项目背景和问题
阅读: [`WORK_SUMMARY.md`](WORK_SUMMARY.md)

#### → 开始验证 demo
阅读: [`phase0_validation/QUICKSTART.md`](phase0_validation/QUICKSTART.md)

#### → 查看实施计划
阅读: [`ROADMAP.md`](ROADMAP.md)

#### → 验证 Windows 技术
阅读: [`phase0_validation/demo_windows_named_handle/README.md`](phase0_validation/demo_windows_named_handle/README.md)

#### → 验证 Linux 技术
阅读: [`phase0_validation/demo_linux_fork_fd/README.md`](phase0_validation/demo_linux_fork_fd/README.md)

#### → 查看原始设计的问题
阅读: [`docs/superpowers/specs/2026-06-11-cross-platform-windows-linux-design.md`](docs/superpowers/specs/2026-06-11-cross-platform-windows-linux-design.md)
对比: WORK_SUMMARY.md "原设计的关键问题"

---

## 📂 文件结构

```
flutter_zero_copy/
├── INDEX.md                          # 本文件：文档索引
├── WORK_SUMMARY.md                   # 工作总结（从这里开始）
├── ROADMAP.md                        # 实施路线图
│
├── docs/superpowers/specs/
│   └── 2026-06-11-cross-platform-windows-linux-design.md  # 原设计
│
├── phase0_validation/
│   ├── README.md                     # Phase 0 总体介绍
│   ├── QUICKSTART.md                 # 快速启动指南 ⭐
│   ├── SUMMARY.md                    # 验证结果总结（待填写）
│   │
│   ├── demo_windows_named_handle/
│   │   ├── README.md                 # Windows demo 说明
│   │   ├── parent.cpp                # 父进程源码
│   │   ├── child.cpp                 # 子进程源码
│   │   └── build.bat                 # 构建脚本
│   │
│   └── demo_linux_fork_fd/
│       ├── README.md                 # Linux demo 说明
│       ├── demo_linux_fork_fd.c      # 单文件 demo
│       └── build.sh                  # 构建脚本
│
├── cube_renderer/                    # 现有渲染器
│   └── main.cpp                      # macOS 实现（已完成）
│
└── macos/Runner/
    └── ZeroCopyTexturePlugin.swift  # macOS Plugin（已完成）
```

---

## ⏱️ 阅读顺序建议

### 第一次阅读（30 分钟）

1. **工作总结** (10 分钟)
   - `WORK_SUMMARY.md` - 了解背景和问题

2. **快速启动** (5 分钟)
   - `phase0_validation/QUICKSTART.md` - 了解如何验证

3. **路线图** (10 分钟)
   - `ROADMAP.md` - 了解实施计划

4. **选择性阅读** (5 分钟)
   - Windows demo README 或 Linux demo README

### 验证前阅读（15 分钟）

1. `phase0_validation/QUICKSTART.md` - 快速启动指南
2. `phase0_validation/demo_windows_named_handle/README.md` (Windows)
   或 `phase0_validation/demo_linux_fork_fd/README.md` (Linux)

### 实施前阅读（1 小时）

1. `WORK_SUMMARY.md` - 完整背景
2. `ROADMAP.md` - 详细计划
3. 对应平台的 demo README
4. 原始设计文档（对比问题）

---

## 🚀 下一步

1. ✅ 阅读 `WORK_SUMMARY.md` - 了解整体情况
2. ✅ 阅读 `phase0_validation/QUICKSTART.md` - 准备验证
3. 🔶 运行验证 demo - Windows 或 Linux
4. 🔶 填写 `phase0_validation/SUMMARY.md` - 记录结果
5. ⏸️ 进入 Phase 2/3 实施

---

**当前状态**: Phase 0 - 技术验证阶段 🔶

**预计完成**: 1-2 天后进入 Phase 2 (Windows 实施)
