// parent.cpp - Windows Named Shared Resource 验证 (父进程)
//
// 功能：
// 1. 创建 D3D11 纹理
// 2. 用 CreateSharedHandle 创建命名共享句柄
// 3. 清除纹理为红色
// 4. 启动子进程 (传递纹理名称)
// 5. 等待子进程修改纹理
// 6. 验证纹理变为蓝色
//
// 编译: cl parent.cpp /EHsc d3d11.lib dxgi.lib /Fe:parent.exe

#include <d3d11_1.h>
#include <dxgi1_2.h>
#include <wrl/client.h>
#include <windows.h>
#include <stdio.h>

using Microsoft::WRL::ComPtr;

#define CHECK_HR(hr, msg) if (FAILED(hr)) { \
    fprintf(stderr, "[PARENT] ERROR: %s (HRESULT=0x%x)\n", msg, hr); \
    return 1; \
}

int main(int argc, char* argv[]) {
    printf("[PARENT] ========================================\n");
    printf("[PARENT] Windows Named Shared Resource 验证\n");
    printf("[PARENT] ========================================\n\n");

    // ── 1. 创建 D3D11 设备 ──────────────────────────────────
    printf("[PARENT] Step 1: 创建 D3D11 设备...\n");

    ComPtr<ID3D11Device> device;
    ComPtr<ID3D11DeviceContext> context;
    D3D_FEATURE_LEVEL featureLevel;

    HRESULT hr = D3D11CreateDevice(
        nullptr,                    // 默认适配器
        D3D_DRIVER_TYPE_HARDWARE,   // 硬件加速
        nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,  // Flutter 需要 BGRA
        nullptr, 0,
        D3D11_SDK_VERSION,
        &device,
        &featureLevel,
        &context
    );
    CHECK_HR(hr, "D3D11CreateDevice 失败");

    printf("[PARENT]   ✅ D3D11 设备创建成功 (Feature Level: 0x%x)\n", featureLevel);

    // ── 2. 创建共享纹理 ─────────────────────────────────────
    printf("[PARENT] Step 2: 创建共享纹理 (800x600 BGRA)...\n");

    D3D11_TEXTURE2D_DESC texDesc = {};
    texDesc.Width = 800;
    texDesc.Height = 600;
    texDesc.MipLevels = 1;
    texDesc.ArraySize = 1;
    texDesc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;  // 与 Flutter 一致
    texDesc.SampleDesc.Count = 1;
    texDesc.SampleDesc.Quality = 0;
    texDesc.Usage = D3D11_USAGE_DEFAULT;
    texDesc.BindFlags = D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
    texDesc.CPUAccessFlags = 0;
    texDesc.MiscFlags = D3D11_RESOURCE_MISC_SHARED_NTHANDLE |  // 关键：命名句柄
                        D3D11_RESOURCE_MISC_SHARED_KEYEDMUTEX;  // 同步机制

    ComPtr<ID3D11Texture2D> texture;
    hr = device->CreateTexture2D(&texDesc, nullptr, &texture);
    CHECK_HR(hr, "CreateTexture2D 失败");

    printf("[PARENT]   ✅ 纹理创建成功 (800x600 BGRA)\n");

    // ── 3. 创建命名共享句柄 ─────────────────────────────────
    printf("[PARENT] Step 3: 创建命名共享句柄...\n");

    ComPtr<IDXGIResource1> dxgiResource;
    hr = texture.As(&dxgiResource);
    CHECK_HR(hr, "QueryInterface IDXGIResource1 失败");

    // 命名句柄 (类似 IOSurface 的全局命名空间)
    const wchar_t* sharedName = L"ZeroCopyTextureDemo";
    HANDLE sharedHandle = NULL;

    hr = dxgiResource->CreateSharedHandle(
        nullptr,                               // 默认安全描述符
        DXGI_SHARED_RESOURCE_READ | DXGI_SHARED_RESOURCE_WRITE,
        sharedName,                            // 命名句柄 (关键!)
        &sharedHandle
    );
    CHECK_HR(hr, "CreateSharedHandle 失败");

    printf("[PARENT]   ✅ 命名共享句柄创建成功\n");
    printf("[PARENT]      名称: %ls\n", sharedName);
    printf("[PARENT]      句柄值: 0x%p (仅用于父进程关闭，子进程用名称打开)\n", sharedHandle);

    // ── 4. 获取 KeyedMutex (用于同步) ────────────────────────
    ComPtr<IDXGIKeyedMutex> keyedMutex;
    hr = texture.As(&keyedMutex);
    CHECK_HR(hr, "QueryInterface IDXGIKeyedMutex 失败");

    // ── 5. 清除纹理为红色 ───────────────────────────────────
    printf("[PARENT] Step 4: 清除纹理为红色...\n");

    ComPtr<ID3D11RenderTargetView> rtv;
    hr = device->CreateRenderTargetView(texture.Get(), nullptr, &rtv);
    CHECK_HR(hr, "CreateRenderTargetView 失败");

    // 获取锁 (key=0 表示初始状态)
    hr = keyedMutex->AcquireSync(0, INFINITE);
    CHECK_HR(hr, "AcquireSync(0) 失败");

    const float red[4] = {1.0f, 0.0f, 0.0f, 1.0f};  // RGBA 红色
    context->ClearRenderTargetView(rtv.Get(), red);
    context->Flush();

    // 释放锁 (key=1 表示父进程完成，子进程可以获取)
    hr = keyedMutex->ReleaseSync(1);
    CHECK_HR(hr, "ReleaseSync(1) 失败");

    printf("[PARENT]   ✅ 纹理已清除为红色 (RGBA: 1.0, 0.0, 0.0, 1.0)\n");

    // ── 6. 启动子进程 ───────────────────────────────────────
    printf("[PARENT] Step 5: 启动子进程...\n");

    STARTUPINFOA si = {sizeof(si)};
    PROCESS_INFORMATION pi = {};

    char cmdLine[256];
    sprintf_s(cmdLine, sizeof(cmdLine), "child.exe");

    BOOL success = CreateProcessA(
        nullptr,        // 应用程序名称
        cmdLine,        // 命令行 (子进程通过名称打开，无需传参数)
        nullptr, nullptr, FALSE,
        CREATE_NEW_CONSOLE,  // 新控制台窗口
        nullptr, nullptr,
        &si, &pi
    );

    if (!success) {
        fprintf(stderr, "[PARENT] ERROR: 启动子进程失败 (错误码: %d)\n", GetLastError());
        fprintf(stderr, "[PARENT]        请确保 child.exe 在同一目录\n");
        CloseHandle(sharedHandle);
        return 1;
    }

    printf("[PARENT]   ✅ 子进程已启动 (PID: %d)\n", pi.dwProcessId);
    printf("[PARENT]   等待子进程修改纹理...\n\n");

    // ── 7. 等待子进程退出 ───────────────────────────────────
    WaitForSingleObject(pi.hProcess, INFINITE);

    DWORD exitCode;
    GetExitCodeProcess(pi.hProcess, &exitCode);
    printf("\n[PARENT] Step 6: 子进程已退出 (退出码: %d)\n", exitCode);

    CloseHandle(pi.hProcess);
    CloseHandle(pi.hThread);

    if (exitCode != 0) {
        fprintf(stderr, "[PARENT] ERROR: 子进程返回错误码，跳过验证\n");
        CloseHandle(sharedHandle);
        return 1;
    }

    // ── 8. 验证纹理已变为蓝色 ───────────────────────────────
    printf("[PARENT] Step 7: 验证纹理颜色 (应为蓝色)...\n");

    // 获取锁 (key=2 表示子进程完成)
    hr = keyedMutex->AcquireSync(2, 5000);
    if (FAILED(hr)) {
        fprintf(stderr, "[PARENT] ERROR: AcquireSync(2) 超时 - 子进程未正确释放锁\n");
        CloseHandle(sharedHandle);
        return 1;
    }

    // 创建 staging texture 用于 CPU 读取
    D3D11_TEXTURE2D_DESC stagingDesc = texDesc;
    stagingDesc.Usage = D3D11_USAGE_STAGING;
    stagingDesc.BindFlags = 0;
    stagingDesc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
    stagingDesc.MiscFlags = 0;

    ComPtr<ID3D11Texture2D> stagingTexture;
    hr = device->CreateTexture2D(&stagingDesc, nullptr, &stagingTexture);
    CHECK_HR(hr, "CreateTexture2D (staging) 失败");

    context->CopyResource(stagingTexture.Get(), texture.Get());

    D3D11_MAPPED_SUBRESOURCE mapped;
    hr = context->Map(stagingTexture.Get(), 0, D3D11_MAP_READ, 0, &mapped);
    CHECK_HR(hr, "Map staging texture 失败");

    // 读取中心像素
    uint32_t* pixels = (uint32_t*)mapped.pData;
    uint32_t centerPixel = pixels[300 * (mapped.RowPitch / 4) + 400];  // 中心点 (400, 300)

    context->Unmap(stagingTexture.Get(), 0);

    // 释放锁
    keyedMutex->ReleaseSync(0);  // 重置为 0

    // 验证颜色 (BGRA 格式: 0xAARRGGBB)
    // 蓝色 = 0xFF0000FF (ARGB) = 0xFFFF0000 (BGRA in memory)
    uint8_t b = (centerPixel >> 0) & 0xFF;
    uint8_t g = (centerPixel >> 8) & 0xFF;
    uint8_t r = (centerPixel >> 16) & 0xFF;
    uint8_t a = (centerPixel >> 24) & 0xFF;

    printf("[PARENT]   中心像素 (400, 300) 颜色:\n");
    printf("[PARENT]     R=%d, G=%d, B=%d, A=%d\n", r, g, b, a);
    printf("[PARENT]     原始值: 0x%08X\n", centerPixel);

    bool isBlue = (b > 250 && r < 5 && g < 5);  // 蓝色分量高，红绿低

    if (isBlue) {
        printf("\n[PARENT] ========================================\n");
        printf("[PARENT] ✅✅✅ 验证成功！ ✅✅✅\n");
        printf("[PARENT] ========================================\n");
        printf("[PARENT] Windows Named Shared Resource 工作正常:\n");
        printf("[PARENT]   • 父进程创建纹理并命名\n");
        printf("[PARENT]   • 子进程通过名称打开\n");
        printf("[PARENT]   • 子进程修改纹理内容\n");
        printf("[PARENT]   • 父进程看到修改后的内容\n");
        printf("[PARENT] \n");
        printf("[PARENT] ✅ 可以进入 Phase 2: Windows 实施\n");
        printf("[PARENT] ========================================\n");
    } else {
        printf("\n[PARENT] ========================================\n");
        printf("[PARENT] ❌❌❌ 验证失败！ ❌❌❌\n");
        printf("[PARENT] ========================================\n");
        printf("[PARENT] 纹理颜色不是蓝色 (期望 B>250, R<5, G<5)\n");
        printf("[PARENT] 可能原因:\n");
        printf("[PARENT]   • 子进程未成功写入纹理\n");
        printf("[PARENT]   • KeyedMutex 同步问题\n");
        printf("[PARENT]   • 纹理格式不匹配\n");
        printf("[PARENT] ========================================\n");
        CloseHandle(sharedHandle);
        return 1;
    }

    // ── 9. 清理 ─────────────────────────────────────────────
    CloseHandle(sharedHandle);

    return 0;
}
