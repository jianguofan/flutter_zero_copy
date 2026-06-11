# Phase 0: 技术可行性验证

## 目标

在正式实施跨平台移植前，验证以下关键技术点：

1. ✅ **Windows Named Shared Resource** - 跨进程纹理共享
2. ✅ **Linux fork + fd 继承** - DMA-BUF fd 传递
3. ✅ **Flutter Engine API** - 确认各平台纹理 API 实际接口

## 验证项目

### 1. Windows Demo (`demo_windows_named_handle/`)

**目的**: 验证 D3D11 named shared resource 可以跨进程访问

**架构**:
```
parent.exe:
  - 创建 D3D11 纹理
  - 用 CreateSharedHandle(lpName="TestTexture") 创建命名句柄
  - 清除纹理为红色
  - 启动 child.exe

child.exe:
  - OpenSharedResourceByName("TestTexture")
  - 读取纹理内容，验证是红色
  - 写入蓝色
  
parent.exe:
  - 等待子进程退出
  - 验证纹理变为蓝色
  
✅ 成功 = 父子进程能双向读写同一纹理
```

**预期结果**: 
- Windows 10+ 支持 ✅
- Windows 8 可能需要降级到 SHARED_KEYEDMUTEX ⚠️

---

### 2. Linux Demo (`demo_linux_fork_fd/`)

**目的**: 验证 fork() 后子进程能继承 DMA-BUF fd 并创建 EGLImage

**架构**:
```
parent (C):
  - gbm_bo_create()
  - gbm_bo_get_fd() → dmaBufFd
  - fork()
  
child (继承 fd):
  - eglCreateImageKHR(EGL_LINUX_DMA_BUF_EXT, dmaBufFd)
  - glEGLImageTargetTexture2DOES()
  - glClear(green)
  
parent:
  - waitpid(child)
  - 验证 gbm_bo 内容为绿色
  
✅ 成功 = 父子进程共享 GPU 内存
```

**预期结果**:
- Mesa driver (Intel/AMD) 支持 ✅
- NVIDIA 545+ 支持 ✅
- NVIDIA 旧版本可能失败 → CPU fallback ⚠️

---

### 3. Flutter API 验证 (`demo_flutter_texture_api/`)

**目的**: 确认 Windows/Linux Flutter API 的实际签名和行为

**方法**:
- 创建最小 Flutter plugin
- Windows: 验证 `FlutterDesktopTextureRegistrarRegisterExternalTexture` callback 调用时机
- Linux: 验证 `FlTextureGL::populate()` 调用时机
- 对比 macOS 现有实现

**预期输出**: 
- 每个平台的完整 API 调用序列
- callback 参数的实际值
- 帧率验证（60fps callback 频率）

---

## 实施顺序

### Day 1 (优先)
1. **Windows Demo** - 最关键，决定整体架构
   - 如果 named handle 不可行 → 需要重新设计

### Day 2
2. **Linux Demo** - 决定是否需要 CPU fallback
   - 如果 fork+fd 可行 → 实施零拷贝路径
   - 如果不可行 → 只做 CPU fallback

### Day 3 (可选)
3. **Flutter API 验证** - 细化实现细节
   - 可以在 Phase 2 实施时并行验证

---

## 成功标准

| Demo | 成功标准 | 失败后备方案 |
|------|---------|------------|
| Windows | 父子进程双向读写纹理，帧率 >60fps | 降级 KEYEDMUTEX 或重新设计 |
| Linux | fork 后子进程能绑定 DMA-BUF 到 GL texture | 放弃零拷贝，只做 CPU fallback |
| Flutter API | callback 每秒调用 60 次，参数正确 | 调整 Plugin 架构 |

---

## 预期时间

- Windows Demo: **4-6 小时** (含调试)
- Linux Demo: **3-4 小时** (需要 Linux 环境)
- Flutter API: **2-3 小时** (最小 plugin)

**总计**: 1-2 个工作日

---

## 下一步

✅ 创建 `demo_windows_named_handle/` 项目  
✅ 编写 parent.cpp / child.cpp  
✅ CMakeLists.txt 支持双可执行文件  
✅ 运行并验证结果  

验证成功后 → 进入 **Phase 2: Windows 实施**
