# Linux DMA-BUF fd 继承验证 Demo

## 目的

验证 Linux 下通过 **fork() + fd 继承** 机制，子进程可以使用父进程创建的 DMA-BUF fd 来访问共享 GPU 内存。

这是 Phase 3 (Linux 实施) 零拷贝路径的关键技术验证。

---

## 架构

```
父进程:
  1. 打开 DRM 设备 (/dev/dri/renderD128)
  2. 创建 GBM buffer object
  3. gbm_bo_get_fd() → 获取 DMA-BUF fd
  4. fork() 子进程 (fd 自动继承)
  5. 等待子进程完成
  6. 验证 gbm_bo 内容为绿色 ✅

子进程 (继承 fd):
  1. 使用继承的 dmaBufFd
  2. eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, fd)
  3. glEGLImageTargetTexture2DOES() → 绑定到 GL texture
  4. 创建 FBO 并渲染绿色
  5. 退出
```

---

## 系统要求

- **操作系统**: Linux (Ubuntu 22.04+, Fedora 38+)
- **GPU**: 支持 DMA-BUF 的显卡
  - ✅ Intel (Mesa driver)
  - ✅ AMD (Mesa driver)
  - ✅ NVIDIA (545+ 驱动)
- **依赖库**:
  - `libgbm-dev` (GBM - Generic Buffer Management)
  - `libegl1-mesa-dev` (EGL)
  - `libgl1-mesa-dev` (OpenGL)
  - `libdrm-dev` (DRM - Direct Rendering Manager)

---

## 安装依赖

### Ubuntu / Debian

```bash
sudo apt update
sudo apt install libgbm-dev libegl1-mesa-dev libgl1-mesa-dev libdrm-dev gcc pkg-config
```

### Fedora / RHEL

```bash
sudo dnf install mesa-libgbm-devel mesa-libEGL-devel mesa-libGL-devel libdrm-devel gcc pkg-config
```

### Arch Linux

```bash
sudo pacman -S mesa libdrm gcc pkg-config
```

---

## 构建步骤

### 方法 1: 使用 build.sh (推荐)

```bash
cd phase0_validation/demo_linux_fork_fd
./build.sh
```

输出文件：`./demo_linux_fork_fd`

### 方法 2: 手动构建

```bash
gcc demo_linux_fork_fd.c -o demo_linux_fork_fd \
    $(pkg-config --cflags --libs gbm egl gl libdrm) \
    -lm
```

---

## 运行验证

```bash
./demo_linux_fork_fd
```

### 预期输出

```
========================================
Linux DMA-BUF fd 继承验证
========================================

[PARENT] Step 1: 打开 DRM 设备...
[PARENT]   ✅ DRM 设备打开成功 (fd: 3)
[PARENT] Step 2: 创建 GBM 设备...
[PARENT]   ✅ GBM 设备创建成功
[PARENT] Step 3: 创建 GBM buffer object (800x600 ARGB8888)...
[PARENT]   ✅ GBM BO 创建成功 (stride: 3200 bytes)
[PARENT] Step 4: 获取 DMA-BUF fd...
[PARENT]   ✅ DMA-BUF fd: 4
[PARENT] Step 5: fork 子进程...
[PARENT]   子进程将继承 fd 4

[CHILD] ========================================
[CHILD] 子进程启动 (PID: 12345)
[CHILD] ========================================

[CHILD] Step 1: 验证继承的 fd...
[CHILD]   dmaBufFd = 4 (从父进程继承)
[CHILD]   ✅ fd 有效
[CHILD] Step 2: 初始化 EGL...
[CHILD]   ✅ EGL 1.5 初始化成功
[CHILD]   ✅ EGL DMA-BUF 扩展加载成功
[CHILD] Step 3: 创建 EGL context...
[CHILD]   ✅ EGL context 创建成功
[CHILD] Step 4: 从 DMA-BUF fd 创建 EGLImage...
[CHILD]   ✅ EGLImage 创建成功
[CHILD] Step 5: 绑定 EGLImage 到 GL texture...
[CHILD]   ✅ GL texture 绑定成功 (texture ID: 1)
[CHILD] Step 6: 渲染绿色到纹理...
[CHILD]   ✅ 纹理已清除为绿色

[CHILD] ========================================
[CHILD] ✅ 子进程完成
[CHILD] ========================================

[PARENT] Step 6: 子进程已退出 (退出码: 0)
[PARENT] Step 7: 验证 gbm_bo 内容 (应为绿色)...
[PARENT]   中心像素 (400, 300) 颜色:
[PARENT]     R=0, G=255, B=0, A=255

========================================
✅✅✅ 验证成功！ ✅✅✅
========================================
Linux fork + DMA-BUF fd 继承工作正常
✅ 可以进入 Phase 3: Linux 实施 (零拷贝路径)
========================================
```

---

## 成功标准

✅ **验证成功**：
- 父进程创建 GBM BO 并获取 DMA-BUF fd
- fork() 后子进程能使用继承的 fd
- 子进程通过 `eglCreateImageKHR` 成功创建 EGLImage
- 子进程渲染到纹理
- 父进程通过 `gbm_bo_map` 读取到绿色像素

**结论**: fork + fd 继承机制可行，可以用于 Flutter 跨进程零拷贝纹理共享。

---

## 故障排除

### 错误: "EGL_EXT_image_dma_buf_import 不支持"

**原因**: 显卡驱动不支持 DMA-BUF import

**解决方案**:
- **Intel/AMD**: 更新到较新的 Mesa 驱动
  ```bash
  sudo apt install mesa-utils
  glxinfo | grep "OpenGL version"  # 检查 Mesa 版本
  ```
- **NVIDIA**: 更新到 545+ 驱动
  ```bash
  nvidia-smi  # 检查驱动版本
  sudo apt install nvidia-driver-550  # 更新驱动
  ```
- **Fallback**: 如果驱动无法更新，改用 CPU fallback 方案

### 错误: "打开 /dev/dri/renderD128 失败"

**原因**: 没有 GPU 或 DRM 设备

**解决方案**:
- 检查设备：`ls -la /dev/dri/`
- 检查权限：`sudo usermod -aG video $USER` (需要重新登录)
- 虚拟机：确保启用了 3D 加速

### 错误: "eglCreateImageKHR 失败"

**原因**: fd 无效或格式不支持

**解决方案**:
- 验证 fd：`ls -l /proc/$$/fd/` 查看进程的 fd 列表
- 尝试其他格式：修改代码中的 `GBM_FORMAT_ARGB8888` 为 `GBM_FORMAT_XRGB8888`
- 检查驱动日志：`dmesg | grep drm`

### 警告: "gbm_bo_map 失败"

**原因**: 某些驱动不支持 CPU mapping（常见于 NVIDIA）

**影响**: 无法验证渲染结果，但不影响核心功能

**解决方案**:
- 这是预期行为
- 子进程渲染成功就表明 DMA-BUF fd 继承工作正常
- 在实际 Flutter 实现中，Flutter Engine 直接通过 GPU 采样纹理，不需要 CPU mapping

---

## 技术细节

### fork() vs Process.start()

| 方案 | fd 继承 | Dart 支持 | 复杂度 |
|------|---------|----------|--------|
| **fork() + exec()** (本 demo) | ✅ 自动 | ⚠️ 需要 dart:ffi | 中等 |
| **Process.start()** | ❌ fd 表清空 | ✅ 原生支持 | 简单 |

**结论**: fork() 是实现零拷贝的必要条件，需要在 Flutter Plugin 中用 dart:ffi 调用 POSIX fork/exec。

### DMA-BUF 格式对应

| Flutter/macOS | Windows | Linux GBM | Linux EGL |
|--------------|---------|-----------|-----------|
| `kCVPixelFormatType_32BGRA` | `DXGI_FORMAT_B8G8R8A8_UNORM` | `GBM_FORMAT_ARGB8888` | `GL_BGRA8` |

**注意**: Linux 的 ARGB8888 在内存中实际是 BGRA 顺序（小端序），与 macOS/Windows 一致。

### EGL DMA-BUF Import 流程

```c
1. gbm_bo_create() → 创建 GPU buffer
2. gbm_bo_get_fd() → 导出为 DMA-BUF fd
3. fork() → 子进程继承 fd
4. eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, fd) → 导入为 EGLImage
5. glEGLImageTargetTexture2DOES() → 绑定到 GL texture
6. glFramebufferTexture2D() → 设为 FBO 渲染目标
7. glClear() / glDraw() → 渲染
8. glFlush() → GPU 同步，父进程可见
```

---

## 替代方案：CPU Fallback

如果验证失败（驱动不支持 DMA-BUF），推荐使用 **CPU fallback** 方案：

**优点**:
- 不需要 fork()，用 `Process.start()` 即可
- 跨所有 Linux 发行版和 GPU 驱动
- 实现简单

**缺点**:
- 不是零拷贝（每帧 CPU → GPU memcpy）
- 性能略低（但 60fps 仍可达成）

**实现**:
- Renderer 通过 `glReadPixels()` 读取帧到 CPU buffer
- 通过 stdout pipe 或 shared memory 传给 Flutter
- Flutter Plugin 用 `FlPixelBufferTexture` 提交

---

## 下一步

### ✅ 验证成功 → Phase 3 选项 A (零拷贝)

- 在 Flutter Plugin 中用 `dart:ffi` 实现 fork/exec
- 实现 `FlTextureGL::populate()` 返回 GL texture ID
- 修改 `cube_renderer` 的 Linux 版本使用 DMA-BUF fd

### ⚠️ 验证失败 → Phase 3 选项 B (CPU fallback)

- 使用 `Process.start()` (简单)
- Renderer 用 `glReadPixels()` 读取像素
- Plugin 用 `FlPixelBufferTexture` (CPU 纹理)
- 在文档中明确标记为"非零拷贝"

---

## 参考资料

- [EGL_EXT_image_dma_buf_import 规范](https://www.khronos.org/registry/EGL/extensions/EXT/EGL_EXT_image_dma_buf_import.txt)
- [GBM (Generic Buffer Management)](https://gitlab.freedesktop.org/mesa/mesa/-/blob/main/src/gbm/main/gbm.h)
- [Linux DMA-BUF 内核文档](https://www.kernel.org/doc/html/latest/driver-api/dma-buf.html)
