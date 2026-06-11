# 跨平台零拷贝 GPU 纹理实施路线图

> 基于对抗审查和技术验证的完整实施计划

---

## 📊 项目概览

| 平台 | 当前状态 | 零拷贝机制 | 预计工作量 |
|------|---------|-----------|----------|
| **macOS** | ✅ 已完成 | IOSurface (全局 ID) | 0 天（不需要修改） |
| **Windows** | 🔶 Phase 0 | Named Shared Resource | 3-5 天 |
| **Linux** | 🔶 Phase 0 | fork+fd 继承 / CPU fallback | 3-7 天 |

**总预计时间**: 7-13 天（含验证）

---

## 🗓️ 分阶段实施计划

### Phase 0: 技术验证 ⏱️ 1-2 天 🔶 **当前阶段**

**目标**: 验证 Windows/Linux 的关键技术可行性

**任务**:
- [x] 创建修正设计文档
- [x] 编写 Windows named handle demo
- [x] 编写 Linux fork+fd demo
- [ ] **在 Windows 环境运行验证**
- [ ] **在 Linux 环境运行验证**
- [ ] 根据验证结果确定实施方案

**输出**:
- ✅ 修正设计文档: `/docs/superpowers/specs/2026-06-11-cross-platform-windows-linux-design-CORRECTED.md`
- ✅ Windows demo: `/phase0_validation/demo_windows_named_handle/`
- ✅ Linux demo: `/phase0_validation/demo_linux_fork_fd/`
- 🔶 验证报告: `/phase0_validation/SUMMARY.md` (待填写)

**决策点**:
- Windows demo 成功 → 进入 Phase 2
- Windows demo 失败 → 评估降级方案或重新设计
- Linux demo 成功 → Phase 3 零拷贝路径
- Linux demo 失败 → Phase 3 CPU fallback 路径

---

### Phase 1: macOS 重构 ⏱️ 0 天 ✅ **已完成**

**目标**: 抽离 macOS 实现到新的 renderer 架构

**状态**: 当前 macOS 实现已可用，无需修改

**跳过原因**:
- 现有实现已经是跨进程架构
- IOSurface 机制与修正设计一致
- 60fps 性能已验证

---

### Phase 2: Windows 实施 ⏱️ 3-5 天 ⏸️ **等待 Phase 0**

**前置条件**: Phase 0 Windows 验证成功

#### 2.1 Windows Plugin (2 天)

**任务**:
- [ ] 创建 `windows/runner/zero_copy_plugin.cpp/h`
- [ ] 实现 D3D11 设备初始化
- [ ] 实现 named shared resource 创建
- [ ] 实现 `FlutterDesktopGpuSurfaceCallback`
- [ ] 实现生命周期管理（dispose, 进程崩溃检测）
- [ ] 实现帧更新 timer (16.67ms)

**关键代码**:
```cpp
// 创建命名共享纹理
wchar_t name[64];
swprintf(name, 64, L"ZeroCopyTexture_%lld", surfaceId);
dxgiResource->CreateSharedHandle(nullptr, GENERIC_ALL, name, &sharedHandle);

// 注册纹理 callback
FlutterDesktopTextureInfo textureInfo = {
    .type = kFlutterDesktopGpuSurfaceTexture,
    .gpu_surface_config = {
        .callback = gpuSurfaceCallback,
        .user_data = this,
    }
};
```

#### 2.2 Windows Renderer (1-2 天)

**任务**:
- [ ] 创建 `cube_renderer/renderer_windows.cpp`
- [ ] 实现 `IRenderer` 接口
- [ ] 用 `OpenSharedResourceByName` 打开纹理
- [ ] 创建 RenderTargetView
- [ ] 移植立方体渲染逻辑
- [ ] 编译 HLSL shaders

**关键代码**:
```cpp
// 通过名称打开共享纹理
std::wstring name = L"ZeroCopyTexture_" + std::to_wstring(surfaceId);
device->OpenSharedResourceByName(name.c_str(), GENERIC_ALL, IID_PPV_ARGS(&texture));
```

#### 2.3 构建系统 (0.5 天)

**任务**:
- [ ] 更新 `windows/CMakeLists.txt`
- [ ] 添加 D3D11/DXGI 链接
- [ ] 支持 x64 + ARM64 双架构
- [ ] 测试构建流程

#### 2.4 验证 (0.5 天)

**任务**:
- [ ] Windows 10 x64 测试
- [ ] Windows 11 ARM64 测试（如果有硬件）
- [ ] 性能测试（60fps 验证）
- [ ] 进程崩溃恢复测试

**成功标准**:
- ✅ 立方体正常显示
- ✅ 鼠标交互流畅
- ✅ 60fps 稳定
- ✅ 进程崩溃后资源正常清理

---

### Phase 3: Linux 实施 ⏱️ 3-7 天 ⏸️ **等待 Phase 0**

**前置条件**: Phase 0 Linux 验证完成

**分支方案**:
- **方案 A** (验证成功): 零拷贝路径 (5-7 天)
- **方案 B** (验证失败): CPU fallback (3-4 天)

#### 方案 A: 零拷贝路径 (5-7 天)

##### 3A.1 Linux Plugin (3 天)

**任务**:
- [ ] 创建 `linux/runner/zero_copy_plugin.cc/h`
- [ ] 实现 GBM buffer object 创建
- [ ] 实现 EGL context 管理
- [ ] 用 dart:ffi 实现 fork/exec wrapper
- [ ] 实现 `FlTextureGL::populate()` 返回 texture ID
- [ ] 实现生命周期管理

**关键代码 (dart:ffi fork)**:
```dart
// Dart 侧用 ffi 调用 fork
import 'dart:ffi' as ffi;

typedef ForkFunc = ffi.Int32 Function();
typedef Fork = int Function();

final fork = dylib.lookupFunction<ForkFunc, Fork>('fork');

int pid = fork();
if (pid == 0) {
  // 子进程: exec cube_renderer
  execl(rendererPath, ...);
}
```

##### 3A.2 Linux Renderer (2 天)

**任务**:
- [ ] 创建 `cube_renderer/renderer_linux.cpp`
- [ ] 实现 EGL + DMA-BUF import
- [ ] 从继承的 fd 创建 EGLImage
- [ ] 绑定到 GL texture 和 FBO
- [ ] 移植立方体渲染逻辑

##### 3A.3 验证 (1-2 天)

**任务**:
- [ ] Ubuntu 22.04 + Intel GPU 测试
- [ ] Fedora + AMD GPU 测试
- [ ] NVIDIA 545+ 测试
- [ ] 性能验证

---

#### 方案 B: CPU Fallback (3-4 天)

##### 3B.1 Linux Plugin (1.5 天)

**任务**:
- [ ] 创建 `linux/runner/zero_copy_plugin.cc/h`
- [ ] 实现 `FlPixelBufferTexture` 子类
- [ ] 实现 shared memory 或 pipe 接收像素数据
- [ ] 用 `Process.start()` 启动 renderer（简单！）
- [ ] 实现生命周期管理

**简化点**:
- ✅ 不需要 dart:ffi
- ✅ 不需要 fork/exec
- ✅ 不需要 GBM/EGL

##### 3B.2 Linux Renderer (1 天)

**任务**:
- [ ] 创建 `cube_renderer/renderer_linux.cpp`
- [ ] 用 `glReadPixels` 读取帧到 CPU buffer
- [ ] 通过 stdout pipe 或 shm 发送给 Flutter
- [ ] 移植立方体渲染逻辑

##### 3B.3 验证 (0.5 天)

**任务**:
- [ ] 跨多个 Linux 发行版测试
- [ ] 性能验证（60fps 是否可达）

---

### Phase 4: 完善与文档 ⏱️ 2-3 天

**前置条件**: Phase 2 和 Phase 3 完成

#### 4.1 跨平台构建脚本 (1 天)

**任务**:
- [ ] 统一的 `build_cube_renderer.sh`
- [ ] 自动检测平台和架构
- [ ] 生成 universal binary (macOS)
- [ ] 多架构支持 (Windows x64/ARM64, Linux x86_64/aarch64)

#### 4.2 错误处理完善 (0.5 天)

**任务**:
- [ ] 所有平台添加健康检查
- [ ] 进程崩溃自动恢复
- [ ] 友好的错误提示

#### 4.3 文档更新 (0.5 天)

**任务**:
- [ ] 更新 README.md
- [ ] 更新 IMPLEMENTATION.md
- [ ] 添加平台特定说明
- [ ] 添加故障排除指南

#### 4.4 性能测试 (1 天)

**任务**:
- [ ] 各平台 fps benchmark
- [ ] CPU/GPU 使用率监控
- [ ] 内存泄漏检测
- [ ] 长时间稳定性测试

---

## 📋 检查清单

### Phase 0 (验证)
- [x] 修正设计文档完成
- [x] Windows demo 代码完成
- [x] Linux demo 代码完成
- [ ] Windows 验证通过
- [ ] Linux 验证通过
- [ ] 验证报告填写

### Phase 2 (Windows)
- [ ] Plugin 实现
- [ ] Renderer 实现
- [ ] 构建系统配置
- [ ] x64 测试通过
- [ ] ARM64 测试通过（可选）
- [ ] 性能达标 (60fps)

### Phase 3 (Linux)
- [ ] Plugin 实现
- [ ] Renderer 实现
- [ ] 构建系统配置
- [ ] Intel/AMD 测试通过
- [ ] NVIDIA 测试通过
- [ ] 性能达标 (60fps 或标记 CPU fallback)

### Phase 4 (完善)
- [ ] 跨平台构建脚本
- [ ] 错误处理完善
- [ ] 文档更新
- [ ] 性能测试报告

---

## 🎯 里程碑

| 里程碑 | 预计日期 | 状态 |
|--------|---------|------|
| Phase 0 完成（验证） | Day 2 | 🔶 进行中 |
| Phase 2 完成（Windows） | Day 7 | ⏸️ 待开始 |
| Phase 3 完成（Linux） | Day 14 | ⏸️ 待开始 |
| Phase 4 完成（完善） | Day 17 | ⏸️ 待开始 |
| **项目完成** | **Day 17** | ⏸️ 待开始 |

---

## 🚨 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| Windows 验证失败 | 低 | 高 | 降级使用 KEYEDMUTEX 或重新设计 |
| Linux DMA-BUF 不支持 | 中 | 中 | 使用 CPU fallback（已有方案） |
| 性能未达 60fps | 低 | 中 | 优化渲染或降低分辨率 |
| 跨 Windows 版本兼容性 | 低 | 中 | 多版本测试，明确最低支持版本 |
| dart:ffi 实现复杂 | 中 | 低 | Linux 改用 CPU fallback |

---

## 📊 成功标准

### 技术指标
- ✅ 所有平台 60fps 稳定
- ✅ macOS/Windows 零拷贝
- ✅ Linux 零拷贝（可选）或 CPU fallback
- ✅ 进程崩溃后资源正常清理
- ✅ 无内存泄漏

### 质量指标
- ✅ 代码通过对抗审查
- ✅ 完整的错误处理
- ✅ 详细的文档
- ✅ 跨平台构建脚本

### 兼容性指标
- ✅ macOS 12+
- ✅ Windows 10+
- ✅ Ubuntu 22.04+ / Fedora 38+
- ✅ Intel/AMD/NVIDIA GPU 支持

---

## 📞 当前行动项

### 立即执行（今天）

1. **Windows 验证** (如果有 Windows 环境)
   ```cmd
   cd phase0_validation\demo_windows_named_handle
   build.bat
   cd build
   parent.exe
   ```

2. **Linux 验证** (如果有 Linux 环境)
   ```bash
   cd phase0_validation/demo_linux_fork_fd
   ./build.sh
   ./demo_linux_fork_fd
   ```

3. **填写验证报告**
   - 在 `phase0_validation/SUMMARY.md` 记录结果
   - 截图或保存完整输出日志

### 验证成功后（明天）

1. 更新项目状态
2. 创建 Phase 2 任务分支
3. 开始 Windows Plugin 实施

---

## 🎉 项目价值

通过这次完整的重新设计和验证：

✅ **避免了原设计的所有阻塞性问题**
✅ **每个平台都有明确可行的技术路径**
✅ **有后备方案应对技术风险**
✅ **详细的分阶段实施计划**
✅ **预期时间从"未知"缩短到"2-3 周"**

现在可以**自信地开始实施**了！🚀
