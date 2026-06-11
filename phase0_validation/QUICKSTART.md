# Phase 0 验证快速启动指南

## 🎯 目标

用 1-2 天时间验证 Windows 和 Linux 的跨进程纹理共享技术是否可行，避免进入 Phase 2/3 后发现技术问题。

---

## 📁 文件结构

```
phase0_validation/
├── README.md                              # Phase 0 总体介绍
├── SUMMARY.md                             # 验证结果总结（完成后填写）
├── QUICKSTART.md                          # 本文件：快速启动
│
├── demo_windows_named_handle/             # Windows 验证
│   ├── README.md                          # Windows demo 详细说明
│   ├── build.bat                          # 构建脚本
│   ├── parent.cpp                         # 父进程（创建纹理）
│   └── child.cpp                          # 子进程（打开纹理）
│
└── demo_linux_fork_fd/                    # Linux 验证
    ├── README.md                          # Linux demo 详细说明
    ├── build.sh                           # 构建脚本
    └── demo_linux_fork_fd.c               # 单文件 demo（fork 测试）
```

---

## ⚡ 30 秒快速开始

### Windows

```cmd
cd phase0_validation\demo_windows_named_handle
build.bat
cd build
parent.exe
```

看到 "✅✅✅ 验证成功！" → 可以进入 Phase 2

### Linux

```bash
cd phase0_validation/demo_linux_fork_fd
./build.sh
./demo_linux_fork_fd
```

看到 "✅✅✅ 验证成功！" → 可以进入 Phase 3 (零拷贝)

---

## 📋 详细步骤

### Windows 验证 (优先级 1)

#### 前置条件
- ✅ Windows 8 或更高版本
- ✅ Visual Studio 2019+ (带 C++ 编译器)
- ✅ 支持 D3D11 的 GPU

#### 步骤

1. **打开 Developer Command Prompt**
   ```
   开始菜单 → Visual Studio 2022 → Developer Command Prompt for VS 2022
   ```

2. **进入目录并构建**
   ```cmd
   cd phase0_validation\demo_windows_named_handle
   build.bat
   ```
   
   预期输出：
   ```
   Building parent.exe...
     [OK] parent.exe
   Building child.exe...
     [OK] child.exe
   Build SUCCESS
   ```

3. **运行验证**
   ```cmd
   cd build
   parent.exe
   ```
   
   会看到两个窗口：
   - 主窗口（parent）：父进程日志
   - 新窗口（child）：子进程日志

4. **查看结果**
   
   ✅ **成功** - 看到：
   ```
   [PARENT] ✅✅✅ 验证成功！ ✅✅✅
   [PARENT] ✅ 可以进入 Phase 2: Windows 实施
   ```
   
   ❌ **失败** - 看到错误信息，查看下方"故障排除"

#### 成功后的决策
- ✅ Windows named shared resource 可行
- ✅ 进入 Phase 2: Windows 实施
- ⏭️ 预计 3-5 天完成 Windows 平台

---

### Linux 验证 (优先级 2)

#### 前置条件
- ✅ Ubuntu 22.04+ / Fedora 38+ / 其他现代 Linux
- ✅ Mesa driver (Intel/AMD) 或 NVIDIA 545+
- ✅ GCC 和开发库

#### 步骤

1. **安装依赖**
   
   Ubuntu/Debian:
   ```bash
   sudo apt update
   sudo apt install libgbm-dev libegl1-mesa-dev libgl1-mesa-dev libdrm-dev gcc pkg-config
   ```
   
   Fedora:
   ```bash
   sudo dnf install mesa-libgbm-devel mesa-libEGL-devel mesa-libGL-devel libdrm-devel gcc pkg-config
   ```

2. **构建**
   ```bash
   cd phase0_validation/demo_linux_fork_fd
   chmod +x build.sh
   ./build.sh
   ```
   
   预期输出：
   ```
   Step 1: 检查依赖...
     ✅ 所有依赖已安装
   Step 2: 编译...
     ✅ 编译成功
   ```

3. **运行验证**
   ```bash
   ./demo_linux_fork_fd
   ```

4. **查看结果**
   
   ✅ **成功** - 看到：
   ```
   ✅✅✅ 验证成功！ ✅✅✅
   Linux fork + DMA-BUF fd 继承工作正常
   ✅ 可以进入 Phase 3: Linux 实施 (零拷贝路径)
   ```
   
   ❌ **失败** - 看到错误或警告

#### 成功后的决策

**如果验证成功** ✅:
- Linux 零拷贝路径可行
- 进入 Phase 3: Linux 实施（需要 dart:ffi）
- ⏭️ 预计 5-7 天完成 Linux 平台（零拷贝）

**如果验证失败** ❌:
- 改用 CPU fallback 方案
- 进入 Phase 3: Linux 实施（CPU fallback）
- ⏭️ 预计 3-4 天完成 Linux 平台（非零拷贝但简单）

---

## 🔧 故障排除

### Windows

#### 错误: "cl.exe not found"
**原因**: 未在 Developer Command Prompt 中运行

**解决**:
```cmd
"C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
```

#### 错误: "OpenSharedResourceByName 失败 (0x80070002)"
**原因**: Windows 版本太旧（< Windows 8）

**解决**:
- 升级到 Windows 10+
- 或使用降级方案（需要修改代码）

#### 错误: "子进程启动失败"
**原因**: child.exe 不在同一目录

**解决**:
```cmd
# 确保在 build\ 目录运行
cd build
dir  # 应该看到 parent.exe 和 child.exe
parent.exe
```

---

### Linux

#### 错误: "缺少依赖: libgbm-dev"
**解决**:
```bash
sudo apt install libgbm-dev libegl1-mesa-dev libgl1-mesa-dev libdrm-dev
```

#### 错误: "EGL_EXT_image_dma_buf_import 不支持"
**原因**: 驱动不支持 DMA-BUF

**解决**:
- Intel/AMD: `sudo apt upgrade` 更新 Mesa
- NVIDIA: `sudo apt install nvidia-driver-550`
- 如果无法更新 → **使用 CPU fallback**（Phase 3 选项 B）

#### 错误: "打开 /dev/dri/renderD128 失败"
**原因**: 权限问题

**解决**:
```bash
sudo usermod -aG video $USER
# 然后重新登录
```

#### 警告: "gbm_bo_map 失败"
**影响**: 无法验证颜色，但核心功能正常

**说明**: 这是预期行为（某些驱动不支持 CPU mapping），不影响实际使用

---

## 📊 验证结果记录

完成验证后，请填写：

### Windows 结果

- [ ] ✅ 验证成功 → 进入 Phase 2
- [ ] ❌ 验证失败 → 需要 Plan B

**系统信息**:
- Windows 版本: ___________
- GPU: ___________
- 错误信息（如果失败）: ___________

### Linux 结果

- [ ] ✅ 验证成功 → Phase 3 零拷贝
- [ ] ❌ 验证失败 → Phase 3 CPU fallback

**系统信息**:
- 发行版: ___________
- 内核版本: ___________
- GPU + 驱动: ___________
- 错误信息（如果失败）: ___________

---

## 🚀 验证成功后的下一步

### 更新文档

```bash
# 在 SUMMARY.md 中记录验证结果
vim phase0_validation/SUMMARY.md
```

### 开始 Phase 2 (Windows)

```bash
# 创建 Windows plugin 骨架
mkdir -p windows/runner
cd windows/runner
# 参考修正设计文档实施
```

### 开始 Phase 3 (Linux)

```bash
# 创建 Linux plugin 骨架
mkdir -p linux/runner
cd linux/runner
# 根据验证结果选择零拷贝或 CPU fallback
```

---

## ⏱️ 预期时间表

| 任务 | 时间 | 状态 |
|------|------|------|
| Windows 验证 | 2-3 小时 | 🔶 待完成 |
| Linux 验证 | 2-3 小时 | 🔶 待完成 |
| 结果分析 | 1 小时 | 🔶 待完成 |
| **Phase 0 总计** | **1 天** | 🔶 进行中 |
| Phase 2 (Windows) | 3-5 天 | ⏸️ 等待验证 |
| Phase 3 (Linux) | 3-7 天 | ⏸️ 等待验证 |

---

## 💡 关键提示

1. **Windows 是关键路径** - 优先验证 Windows
2. **Linux 有后备方案** - 失败了也能用 CPU fallback
3. **macOS 已完成** - 不需要验证
4. **并行验证** - Windows 和 Linux 可以同时测试（如果有两台机器）
5. **记录日志** - 验证失败时保存完整输出，方便诊断

---

## 📞 需要帮助？

遇到问题时：

1. 查看对应 demo 的 `README.md` 的"故障排除"章节
2. 检查系统和驱动版本是否符合要求
3. 收集完整的错误日志和系统信息
4. 描述具体的失败现象

根据验证结果，我会提供针对性的解决方案或调整实施计划。

---

**现在就开始验证吧！** 🚀

选择你当前的平台：
- Windows → `cd demo_windows_named_handle && build.bat`
- Linux → `cd demo_linux_fork_fd && ./build.sh`
