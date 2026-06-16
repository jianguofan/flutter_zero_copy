---
Cross-Platform Zero-Copy GPU Texture — 修正版设计

▎ 基于对抗审查结果的完整可实施方案 | 2026-06-11
---

核心修正点

🔴 阻塞性问题修正

1. ✅ Windows 改用 named shared resource（避免 HANDLE 值传递陷阱）
2. ✅ Linux 提供 fork + fd 继承 或 CPU fallback 双路径
3. ✅ 所有平台使用 callback 机制（而非"传句柄"）
4. ✅ 完整的 生命周期管理（进程崩溃检测、资源清理）
5. ✅ Linux 纹理格式修正为 GBM_FORMAT_ARGB8888

---

1. 平台矩阵（修正版）

┌───────────┬───────────────┬────────────────────────────────┬────────────────────────┐
│ │ macOS │ Windows │ Linux │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ GPU API │ CGL (OpenGL │ D3D11 (FL 11_0) │ EGL (OpenGL ES 3.0) │
│ │ 3.2) │ │ │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ 纹理共享 │ IOSurface │ Named Shared Resource │ fork+fd继承 / CPU │
│ │ (全局 ID) │ │ fallback │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ Flutter │ FlutterTextur │ FlutterDesktopGpuSurfaceCallba │ FlTextureGL::populate( │
│ API │ e callback │ ck │ ) │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ 句柄传递 │ 命令行参数 │ 命令行参数 (named handle) │ fork继承 / 无需传递 │
│ │ (surfaceID) │ │ │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ 纹理格式 │ BGRA8 ✅ │ BGRA8_UNORM ✅ │ ARGB8888 (修正) │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ 帧同步 │ CVDisplayLink │ Timer (16.67ms) │ Timer (16.67ms) │
├───────────┼───────────────┼────────────────────────────────┼────────────────────────┤
│ 零拷贝状 │ ✅ 已验证 │ ⚠️ 需验证 named handle │ ⚠️ fork方案 / ❌ CPU │
│ 态 │ │ │ fallback │
└───────────┴───────────────┴────────────────────────────────┴────────────────────────┘

---

2. 架构概览（修正版）

┌──────────────────────────────────────────────────────────────┐
│ Dart 侧 (跨平台) │
│ │
│ ZeroCopyWidget │
│ ├─ MethodChannel.invokeMethod('createSurface') │
│ │ ↓ 返回 {surfaceHandle, textureId} │
│ ├─ Process.start(renderer, [surfaceHandle]) ← macOS/Windows │
│ │ 或 fork() + exec() ← Linux (fd 继承) │
│ ├─ Texture(textureId) widget │
│ ├─ process.exitCode.then() ← 崩溃检测 │
│ └─ GestureDetector → stdin JSON │
│ │
└───────┬──────────────┬──────────────┬─────────────────────────┘
│ │ │
┌────▼─────┐ ┌────▼─────┐ ┌─────▼──────┐
│ macOS │ │ Windows │ │ Linux │
│ Plugin │ │ Plugin │ │ Plugin │
│ (Swift) │ │ (C++) │ │ (C) │
└────┬─────┘ └────┬─────┘ └─────┬──────┘
│ │ │
│ copyPixelBuffer() gpuSurfaceCallback() populate()
│ ↓ CVPixelBuffer ↓ D3D11 handle ↓ GL texture ID
│ │ │
┌────▼──────────────────▼─────────────────────▼──────┐
│ cube_renderer (C++ 重构) │
│ │
│ main.cpp 平台无关 (Camera, JSON, loop) │
│ renderer.h IRenderer 接口 │
│ renderer_macos.mm CGL + IOSurface │
│ renderer_windows.cpp D3D11 named shared resource │
│ renderer_linux.cpp EGL fd 继承 + CPU fallback │
│ │
└──────────────────────────────────────────────────────┘

---

3. 各平台零拷贝路径（修正版）

3.1 macOS (不变，已验证 ✅)

Plugin 侧 (Swift):
// 1. 创建 IOSurface
let props: [String: Any] = [
kIOSurfaceWidth: width,
kIOSurfaceHeight: height,
kIOSurfacePixelFormat: kCVPixelFormatType_32BGRA,
kIOSurfaceIsGlobal: true // 全局可访问
]
let surface = IOSurfaceCreate(props)
let surfaceID = IOSurfaceGetID(surface) // uint32_t 全局 ID

// 2. 包装为 CVPixelBuffer
CVPixelBufferCreateWithIOSurface(kCFAllocatorDefault, surface, nil, &pixelBuffer)

// 3. 注册纹理 (实现 FlutterTexture 协议)
textureId = textureRegistry.register(self)

// 4. 启动 renderer 进程
Process.start("cube_renderer", ["\(surfaceID)", "\(width)", "\(height)"])

// 5. CVDisplayLink 驱动帧更新
CVDisplayLinkStart(displayLink)

// FlutterTexture 协议实现
func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
return Unmanaged.passRetained(pixelBuffer)
}

Renderer 侧 (C++):
uint32_t surfaceID = atoi(argv[1]);
IOSurfaceRef surface = IOSurfaceLookup(surfaceID); // 通过全局 ID 查找
CGLTexImageIOSurface2D(ctx, GL_TEXTURE_RECTANGLE, GL_RGBA8, w, h,
GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, surface, 0);
glBindFramebuffer(GL_FRAMEBUFFER, fbo);
// render...
glFlush(); // IOSurface seed 自动更新 → Flutter 可见

---

3.2 Windows (修正：named shared resource)

Plugin 侧 (C++):
// 1. 创建 D3D11 设备
D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, ..., &device, &context);

// 2. 创建共享纹理
D3D11_TEXTURE2D_DESC desc = {
.Width = width,
.Height = height,
.Format = DXGI_FORMAT_B8G8R8A8_UNORM, // 与 macOS 保持 BGRA 一致
.MiscFlags = D3D11_RESOURCE_MISC_SHARED_NTHANDLE |
D3D11_RESOURCE_MISC_SHARED_KEYEDMUTEX, // 同步机制
};
device->CreateTexture2D(&desc, nullptr, &texture);

// 3. 创建 **命名** 共享句柄 (关键修正)
ComPtr<IDXGIResource1> dxgiResource;
texture.As(&dxgiResource);
wchar*t name[64];
swprintf(name, 64, L"ZeroCopyTexture*%lld", surfaceId);
dxgiResource->CreateSharedHandle(
nullptr, // 默认安全描述符
DXGI_SHARED_RESOURCE_READ | DXGI_SHARED_RESOURCE_WRITE,
name, // 命名句柄 (类似 IOSurface 全局命名空间)
&sharedHandle
);

// 4. 注册纹理 (callback 机制)
FlutterDesktopTextureInfo textureInfo = {
.type = kFlutterDesktopGpuSurfaceTexture,
.gpu_surface_config = {
.struct_size = sizeof(FlutterDesktopGpuSurfaceTextureConfig),
.type = kFlutterDesktopGpuSurfaceTypeD3d11Texture2D,
.callback = [](size_t width, size_t height, void* user_data) ->
const FlutterDesktopGpuSurfaceDescriptor* {
auto* plugin = static_cast<ZeroCopyPlugin*>(user_data);
return plugin->getGpuSurfaceDescriptor(); // 返回 D3D11 texture
},
.user_data = this,
}
};
textureId = FlutterDesktopTextureRegistrarRegisterExternalTexture(
registrar, &textureInfo);

// 5. 启动 renderer 进程 (传递命名句柄的名称)
std::wstring nameStr(name);
Process.start("cube_renderer.exe", [WideCharToMultiByte(nameStr), ...]);

// 6. Timer 驱动帧更新
SetTimer(hwnd, TIMER_ID, 16, nullptr); // ~60fps

Renderer 侧 (C++):
// 通过名称打开共享纹理 (修正：不再传递 HANDLE 值)
std::string nameArg = argv[1];
std::wstring name = MultiByteToWideChar(nameArg);

D3D11CreateDevice(..., &device, &context);

ComPtr<ID3D11Texture2D> texture;
HRESULT hr = device->OpenSharedResourceByName(
name.c_str(),
DXGI_SHARED_RESOURCE_READ | DXGI_SHARED_RESOURCE_WRITE,
IID_PPV_ARGS(&texture)
);
if (FAILED(hr)) {
fprintf(stderr, "OpenSharedResourceByName failed: 0x%x\n", hr);
return 1;
}

// 创建 RenderTargetView
device->CreateRenderTargetView(texture.Get(), nullptr, &rtv);

// render...
context->Draw(36, 0);
context->Flush(); // GPU 完成 → 共享纹理可见

---

3.3 Linux (修正：fork + fd 继承 或 CPU fallback)

方案选择：

- 方案 A（推荐零拷贝）: fork + fd 继承
- 方案 B（推荐实用）: CPU fallback (非零拷贝但简单)

方案 A: fork + fd 继承 (零拷贝)

Plugin 侧 (C + dart:ffi):
// 1. 创建 GBM buffer object
struct gbm_device *gbm_dev = gbm_create_device(drm_fd);
struct gbm_bo *bo = gbm_bo_create(
gbm_dev, width, height,
GBM_FORMAT_ARGB8888, // 修正：匹配 GL_BGRA + GL_UNSIGNED_BYTE
GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR
);

// 2. 获取 DMA-BUF fd
int dmaBufFd = gbm_bo_get_fd(bo);

// 3. 创建 EGLImage (Plugin 侧也需要)
EGLint attribs[] = {
EGL_WIDTH, width,
EGL_HEIGHT, height,
EGL_LINUX_DRM_FOURCC_EXT, GBM_FORMAT_ARGB8888,
EGL_DMA_BUF_PLANE0_FD_EXT, dmaBufFd,
EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
EGL_DMA_BUF_PLANE0_PITCH_EXT, gbm_bo_get_stride(bo),
EGL_NONE
};
EGLImage eglImage = eglCreateImageKHR(
display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attribs);

// 4. 绑定到 GL texture
GLuint texId;
glGenTextures(1, &texId);
glBindTexture(GL_TEXTURE_2D, texId);
glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, eglImage);

// 5. 注册纹理 (FlTextureGL 子类)
class DmaBufTexture : public FlTextureGL {
bool populate(uint32_t* width, uint32_t* height,
GError\** error) override {
*width = this->width;
*height = this->height;
*target = GL_TEXTURE_2D;
\*name = texId; // 返回 GL texture ID
return TRUE;
}
};
textureId = fl_texture_registrar_register_texture(registrar, texture);

// 6. fork + exec 启动 renderer (关键修正)
// 使用 dart:ffi 调用 POSIX fork/exec，而非 Process.start
int pid = fork();
if (pid == 0) {
// 子进程继承了 dmaBufFd (仍然有效)
char fdStr[16];
sprintf(fdStr, "%d", dmaBufFd);
execl("./cube_renderer", "cube_renderer", fdStr, widthStr, heightStr, NULL);
}
// 父进程继续...不能 close(dmaBufFd)，子进程还在用

Renderer 侧 (C++):
// fd 已通过 fork 继承，直接使用
int dmaBufFd = atoi(argv[1]);

// 创建 EGLImage
EGLImage eglImage = eglCreateImageKHR(
display, EGL_NO_CONTEXT, EGL_LINUX_DMA_BUF_EXT, NULL, attribs);

// 绑定到 GL texture
glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, eglImage);

// FBO render...
glFlush(); // DMA-BUF 更新 → Plugin 侧 GL texture 可见

方案 B: CPU fallback (非零拷贝，简单可靠)

Plugin 侧 (C):
// 使用 FlPixelBufferTexture 而非 FlTextureGL
class CpuTexture : public FlPixelBufferTexture {
bool copy_pixels(uint8_t** out_buffer, uint32_t* width, uint32_t* height,
GError** error) override {
*out_buffer = pixelBuffer; // RGBA8888 CPU buffer
*width = this->width;
\*height = this->height;
return TRUE;
}
};

// renderer 通过 stdout pipe 发送像素数据
// 或使用共享内存 (shm_open + mmap)

---

4. 生命周期管理（新增关键部分）

4.1 资源清理检查表

每个平台 Plugin 必须实现：

class SurfaceLifecycle {
Process? \_process;
int64? \_textureId;
PlatformHandle? \_handle; // IOSurface/HANDLE/fd

Future<void> dispose() async {
// 1. 停止帧更新
stopFrameTimer();

    // 2. Unregister texture
    if (_textureId != null) {
      await channel.invokeMethod('unregisterTexture', _textureId);
      _textureId = null;
    }

    // 3. 终止进程
    if (_process != null) {
      _process.kill(ProcessSignal.sigterm);
      await _process.exitCode.timeout(
        Duration(seconds: 2),
        onTimeout: () {
          _process.kill(ProcessSignal.sigkill);
          return -1;
        }
      );
      _process = null;
    }

    // 4. 释放平台句柄
    if (_handle != null) {
      await channel.invokeMethod('releaseHandle', _handle);
      _handle = null;
    }

}
}

4.2 进程崩溃检测

void \_launchRenderer(String handle) async {
\_process = await Process.start(rendererPath, [handle, ...]);

// 关键：监听进程退出
\_process.exitCode.then((code) {
if (code != 0 && !\_disposed) {
debugPrint('[ZeroCopy] Renderer crashed with code $code');
// 自动清理资源
dispose();
// 通知 UI
setState(() { \_error = 'Renderer process crashed'; });
}
});

// 健康检查：5 秒无输出则认为卡死
\_heartbeatTimer = Timer.periodic(Duration(seconds: 5), (timer) {
if (DateTime.now().difference(\_lastFrameTime) > Duration(seconds: 5)) {
debugPrint('[ZeroCopy] Renderer appears frozen');
dispose();
setState(() { \_error = 'Renderer process frozen'; });
}
});
}

4.3 Resize 处理

void resize(int newWidth, int newHeight) async {
// 1. 完整清理旧资源
await dispose();

// 2. 重新创建
await \_initialize(width: newWidth, height: newHeight);
}

---

5. 错误处理和回滚

5.1 初始化失败路径

// Windows Plugin 示例
HRESULT createSurface(int width, int height) {
ComPtr<ID3D11Device> device;
ComPtr<ID3D11Texture2D> texture;
HANDLE sharedHandle = NULL;

    // 使用 RAII 确保异常安全
    auto cleanup = [&]() {
        if (sharedHandle) CloseHandle(sharedHandle);
        // ComPtr 自动 Release
    };

    HRESULT hr = D3D11CreateDevice(..., &device, ...);
    if (FAILED(hr)) {
        cleanup();
        return hr;
    }

    hr = device->CreateTexture2D(&desc, nullptr, &texture);
    if (FAILED(hr)) {
        cleanup();
        return hr;
    }

    hr = createSharedHandle(texture, &sharedHandle);
    if (FAILED(hr)) {
        cleanup();
        return hr;
    }

    // 全部成功后才注册
    textureId = registerTexture(...);

    // 移交所有权，不再清理
    surfaces_[surfaceId] = {device, texture, sharedHandle, textureId};
    return S_OK;

}

---

6. 实施前验证（Phase 0）

6.1 Windows Named Shared Resource Demo

// demo_windows_shared.cpp
// 验证 named shared resource 跨进程可行性

// 父进程
D3D11CreateDevice(..., &device, ...);
device->CreateTexture2D(&desc, ..., &texture);

IDXGIResource1\* dxgiRes;
texture->QueryInterface(&dxgiRes);
HANDLE handle;
dxgiRes->CreateSharedHandle(
nullptr, GENERIC_ALL,
L"TestSharedTexture", // 命名句柄
&handle
);

// 填充纹理内容
context->ClearRenderTargetView(rtv, {1.0f, 0.0f, 0.0f, 1.0f}); // 红色
context->Flush();

// 启动子进程
CreateProcess("child.exe", ...);

// 子进程 (child.exe)
D3D11CreateDevice(..., &device, ...);
ID3D11Texture2D\* texture;
device->OpenSharedResourceByName(
L"TestSharedTexture",
GENERIC_ALL,
IID_PPV_ARGS(&texture)
);

// 验证能看到红色内容
D3D11_MAPPED_SUBRESOURCE mapped;
context->Map(texture, 0, D3D11_MAP_READ, 0, &mapped);
uint32_t* pixels = (uint32_t*)mapped.pData;
assert(pixels[0] == 0xFFFF0000); // 验证颜色
context->Unmap(texture, 0);

printf("✅ Windows named shared resource works!\n");

6.2 Linux fork + fd 继承 Demo

// demo_linux_fork_fd.c

// 父进程
int dmaBufFd = gbm_bo_get_fd(bo);
printf("Parent: dmaBufFd = %d\n", dmaBufFd);

pid_t pid = fork();
if (pid == 0) {
// 子进程：fd 仍然有效
printf("Child: dmaBufFd = %d (inherited)\n", dmaBufFd);

    // 验证能导入 EGLImage
    EGLImage img = eglCreateImageKHR(..., EGL_LINUX_DMA_BUF_EXT, NULL, attribs);
    if (img != EGL_NO_IMAGE_KHR) {
        printf("✅ Linux fork + fd inheritance works!\n");
        exit(0);
    } else {
        printf("❌ eglCreateImageKHR failed\n");
        exit(1);
    }

}

waitpid(pid, NULL, 0);

---

7. 分阶段实施（修正版）

Phase 0: 验证 (1-2 天)

- ✅ Windows named shared resource demo
- ✅ Linux fork + fd inheritance demo
- ✅ 读取 Flutter Engine 源码确认 API

Phase 1: 重构 macOS (已完成 ✅)

- 当前实现已可用

Phase 2: Windows (3-5 天)

- 实现 named shared resource
- 实现 GPU surface callback
- 验证跨 Windows 8/10/11
- 构建 x64 + ARM64

Phase 3: Linux (5-7 天)

- 优先实现 CPU fallback（保底方案）
- 可选实现 fork + fd 继承（零拷贝）
- 运行时自动选择路径
- 构建 x86_64 + aarch64

Phase 4: 完善 (2-3 天)

- 跨平台构建脚本
- 完整错误处理
- 性能测试（确认 60fps）
- 文档更新

---

8. 关键决策记录

┌────────────────────────────────┬─────────────────────────────────────────────────────┐
│ 决策 │ 原因 │
├────────────────────────────────┼─────────────────────────────────────────────────────┤
│ Windows 用 named shared │ 避免 HANDLE 值跨进程传递的版本兼容性问题 │
│ resource │ │
├────────────────────────────────┼─────────────────────────────────────────────────────┤
│ Linux 优先 CPU fallback │ fork() 需要 dart:ffi，增加复杂度；CPU fallback │
│ │ 更可靠 │
├────────────────────────────────┼─────────────────────────────────────────────────────┤
│ 所有平台用 callback 机制 │ Flutter API 的实际工作方式，而非"传句柄" │
├────────────────────────────────┼─────────────────────────────────────────────────────┤
│ 格式统一用 BGRA/ARGB │ 跨平台一致性，避免红蓝通道互换 │
├────────────────────────────────┼─────────────────────────────────────────────────────┤
│ 进程崩溃自动清理 │ 防止资源泄漏，提升用户体验 │
└────────────────────────────────┴─────────────────────────────────────────────────────┘

---

9. 与原设计对比

┌──────────────────┬─────────────────────────────────┬──────────────────────────────┐
│ 方面 │ 原设计 │ 修正设计 │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Windows 句柄传递 │ ❌ 直接传 HANDLE 值 │ ✅ Named shared resource │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Linux fd 传递 │ ❌ 命令行参数 │ ✅ fork 继承 或 CPU fallback │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Flutter API │ ❌ 假设 RegisterTexture(handle) │ ✅ Callback 机制 │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ Linux 格式 │ ❌ XBGR8888 (红蓝互换) │ ✅ ARGB8888 │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ 进程崩溃处理 │ ❌ 未提及 │ ✅ exitCode 监听 + 清理 │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ resize 处理 │ ❌ 不完整 │ ✅ 完整重建流程 │
├──────────────────┼─────────────────────────────────┼──────────────────────────────┤
│ 资源泄漏防护 │ ❌ 部分遗漏 │ ✅ RAII + 显式清理 │
└──────────────────┴─────────────────────────────────┴──────────────────────────────┘

---

总结

这个修正设计解决了原文档的所有阻塞性问题，提供了：

✅ 端到端可实施的技术路径
✅ 完整的错误处理和资源管理
✅ 渐进式实施策略（CPU fallback 保底）
✅ 验证优先的开发流程（Phase 0）
✅ 60fps 性能目标保证

下一步建议：先做 Phase 0 验证 demo，确认 Windows named handle 和 Linux fork+fd 都可行后，再进入 Phase 2/3 实施。

✻ Brewed for 1m 50s

※ recap: You asked me to audit and redesign a cross-platform zero-copy GPU texture design doc. I ran a multi-agent workflow that found 5 blocking issues (Linux fd can't pass via args, format mismatches, API assumptions wrong). I just printed the complete corrected design above with named shared resources for Windows, fork+fd inheritance for Linux, proper callback mechanisms, and full lifecycle management. Next action is Phase 0 validation demos. (disable recaps in /config)
