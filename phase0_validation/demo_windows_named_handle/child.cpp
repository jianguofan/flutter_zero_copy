// child.cpp - Windows Named Shared Resource 验证 (子进程)
//
// 功能：
// 1. 通过名称打开父进程创建的共享纹理
// 2. 验证纹理是红色 (父进程设置)
// 3. 清除纹理为蓝色
// 4. 退出，让父进程验证
//
// 编译: cl child.cpp /EHsc d3d11.lib dxgi.lib /Fe:child.exe

#include <d3d11_1.h>
#include <dxgi1_2.h>
#include <wrl/client.h>
#include <windows.h>
#include <stdio.h>

using Microsoft::WRL::ComPtr;

#define CHECK_HR(hr, msg) if (FAILED(hr)) { \
    fprintf(stderr, "[CHILD] ERROR: %s (HRESULT=0x%x)\n", msg, hr); \
    return 1; \
}

int main(int argc, char* argv[]) {
    printf("[CHILD] ========================================\n");
    printf("[CHILD] 子进程启动\n");
    printf("[CHILD] ========================================\n\n");

    // ── 1. 创建 D3D11 设备 ──────────────────────────────────
    printf("[CHILD] Step 1: 创建 D3D11 设备...\n");

    ComPtr<ID3D11Device> device;
    ComPtr<ID3D11DeviceContext> context;
    D3D_FEATURE_LEVEL featureLevel;

    HRESULT hr = D3D11CreateDevice(
        nullptr,
        D3D_DRIVER_TYPE_HARDWARE,
        nullptr,
        D3D11_CREATE_DEVICE_BGRA_SUPPORT,
        nullptr, 0,
        D3D11_SDK_VERSION,
        &device,
        &featureLevel,
        &context
    );
    CHECK_HR(hr, "D3D11CreateDevice 失败");

    printf("[CHILD]   ✅ D3D11 设备创建成功\n");

    // ── 2. 通过名称打开共享纹理 (关键!) ─────────────────────
    printf("[CHILD] Step 2: 通过名称打开共享纹理...\n");

    const wchar_t* sharedName = L"ZeroCopyTextureDemo";
    printf("[CHILD]   名称: %ls\n", sharedName);

    ComPtr<ID3D11Texture2D> texture;
    hr = device->OpenSharedResourceByName(
        sharedName,                            // 命名句柄 (父进程创建的)
        DXGI_SHARED_RESOURCE_READ | DXGI_SHARED_RESOURCE_WRITE,
        IID_PPV_ARGS(&texture)
    );

    if (FAILED(hr)) {
        fprintf(stderr, "[CHILD] ERROR: OpenSharedResourceByName 失败 (HRESULT=0x%x)\n", hr);
        fprintf(stderr, "[CHILD]        可能原因:\n");
        fprintf(stderr, "[CHILD]          • Windows 版本不支持 named shared resource (需要 Windows 8+)\n");
        fprintf(stderr, "[CHILD]          • 父进程未创建该名称的纹理\n");
        fprintf(stderr, "[CHILD]          • 权限问题\n");
        return 1;
    }

    printf("[CHILD]   ✅ 共享纹理打开成功\n");

    // 获取纹理描述
    D3D11_TEXTURE2D_DESC texDesc;
    texture->GetDesc(&texDesc);
    printf("[CHILD]   纹理信息: %dx%d, 格式=0x%x\n",
           texDesc.Width, texDesc.Height, texDesc.Format);

    // ── 3. 获取 KeyedMutex ──────────────────────────────────
    ComPtr<IDXGIKeyedMutex> keyedMutex;
    hr = texture.As(&keyedMutex);
    CHECK_HR(hr, "QueryInterface IDXGIKeyedMutex 失败");

    // ── 4. 验证纹理是红色 ───────────────────────────────────
    printf("[CHILD] Step 3: 验证纹理颜色 (应为红色)...\n");

    // 获取锁 (key=1，父进程释放时设为 1)
    hr = keyedMutex->AcquireSync(1, 5000);
    if (FAILED(hr)) {
        fprintf(stderr, "[CHILD] ERROR: AcquireSync(1) 超时 - 父进程未正确释放锁\n");
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
    uint32_t centerPixel = pixels[300 * (mapped.RowPitch / 4) + 400];

    context->Unmap(stagingTexture.Get(), 0);

    uint8_t b = (centerPixel >> 0) & 0xFF;
    uint8_t g = (centerPixel >> 8) & 0xFF;
    uint8_t r = (centerPixel >> 16) & 0xFF;
    uint8_t a = (centerPixel >> 24) & 0xFF;

    printf("[CHILD]   中心像素颜色: R=%d, G=%d, B=%d, A=%d\n", r, g, b, a);

    bool isRed = (r > 250 && g < 5 && b < 5);
    if (!isRed) {
        fprintf(stderr, "[CHILD] WARNING: 纹理颜色不是红色！\n");
        fprintf(stderr, "[CHILD]          期望 R>250, G<5, B<5，但得到 R=%d, G=%d, B=%d\n", r, g, b);
        // 继续执行，但标记为警告
    } else {
        printf("[CHILD]   ✅ 纹理颜色正确 (红色)\n");
    }

    // ── 5. 清除纹理为蓝色 ───────────────────────────────────
    printf("[CHILD] Step 4: 清除纹理为蓝色...\n");

    ComPtr<ID3D11RenderTargetView> rtv;
    hr = device->CreateRenderTargetView(texture.Get(), nullptr, &rtv);
    CHECK_HR(hr, "CreateRenderTargetView 失败");

    const float blue[4] = {0.0f, 0.0f, 1.0f, 1.0f};  // RGBA 蓝色
    context->ClearRenderTargetView(rtv.Get(), blue);
    context->Flush();

    printf("[CHILD]   ✅ 纹理已清除为蓝色\n");

    // 释放锁 (key=2，通知父进程可以读取)
    hr = keyedMutex->ReleaseSync(2);
    CHECK_HR(hr, "ReleaseSync(2) 失败");

    // ── 6. 退出 ─────────────────────────────────────────────
    printf("\n[CHILD] ========================================\n");
    printf("[CHILD] ✅ 子进程完成\n");
    printf("[CHILD] ========================================\n");
    printf("[CHILD] 操作摘要:\n");
    printf("[CHILD]   • 通过名称打开共享纹理 ✅\n");
    printf("[CHILD]   • 验证父进程设置的红色 %s\n", isRed ? "✅" : "⚠️");
    printf("[CHILD]   • 修改纹理为蓝色 ✅\n");
    printf("[CHILD] \n");
    printf("[CHILD] 等待父进程验证...\n");
    printf("[CHILD] ========================================\n");

    return 0;
}
