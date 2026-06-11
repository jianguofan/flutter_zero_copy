# Windows Named Shared Resource 验证 Demo

## 目的

验证 Windows D3D11 的 **Named Shared Resource** 机制可以在跨进程间共享 GPU 纹理。

这是 Phase 2 (Windows 实施) 的关键技术验证。

---

## 架构

```
parent.exe:
  1. 创建 D3D11 纹理
  2. CreateSharedHandle(lpName="ZeroCopyTextureDemo") 
  3. 清除纹理为红色
  4. 启动 child.exe
  5. 等待子进程完成
  6. 验证纹理变为蓝色 ✅

child.exe:
  1. OpenSharedResourceByName("ZeroCopyTextureDemo")
  2. 验证纹理是红色
  3. 清除纹理为蓝色
  4. 退出
```

---

## 系统要求

- **操作系统**: Windows 8 或更高版本 (Windows 10/11 推荐)
- **GPU**: 支持 D3D11 Feature Level 11.0+
- **编译器**: Visual Studio 2019 或更高版本

---

## 构建步骤

### 方法 1: 使用 build.bat (推荐)

1. 打开 **"Developer Command Prompt for VS 2022"**
   - 开始菜单 → Visual Studio 2022 → Developer Command Prompt

2. 进入此目录：
   ```cmd
   cd phase0_validation\demo_windows_named_handle
   ```

3. 运行构建脚本：
   ```cmd
   build.bat
   ```

4. 输出文件：
   ```
   build\parent.exe
   build\child.exe
   ```

### 方法 2: 手动构建

```cmd
mkdir build
cd build

cl ..\parent.cpp /EHsc d3d11.lib dxgi.lib /Fe:parent.exe
cl ..\child.cpp /EHsc d3d11.lib dxgi.lib /Fe:child.exe

cd ..
```

---

## 运行验证

```cmd
cd build
parent.exe
```

### 预期输出

```
[PARENT] ========================================
[PARENT] Windows Named Shared Resource 验证
[PARENT] ========================================

[PARENT] Step 1: 创建 D3D11 设备...
[PARENT]   ✅ D3D11 设备创建成功 (Feature Level: 0xb000)
[PARENT] Step 2: 创建共享纹理 (800x600 BGRA)...
[PARENT]   ✅ 纹理创建成功 (800x600 BGRA)
[PARENT] Step 3: 创建命名共享句柄...
[PARENT]   ✅ 命名共享句柄创建成功
[PARENT]      名称: ZeroCopyTextureDemo
[PARENT] Step 4: 清除纹理为红色...
[PARENT]   ✅ 纹理已清除为红色
[PARENT] Step 5: 启动子进程...
[PARENT]   ✅ 子进程已启动 (PID: 12345)

[子进程窗口显示:]
[CHILD] Step 2: 通过名称打开共享纹理...
[CHILD]   ✅ 共享纹理打开成功
[CHILD] Step 3: 验证纹理颜色 (应为红色)...
[CHILD]   ✅ 纹理颜色正确 (红色)
[CHILD] Step 4: 清除纹理为蓝色...
[CHILD]   ✅ 纹理已清除为蓝色

[PARENT] Step 6: 子进程已退出 (退出码: 0)
[PARENT] Step 7: 验证纹理颜色 (应为蓝色)...
[PARENT]   中心像素 (400, 300) 颜色:
[PARENT]     R=0, G=0, B=255, A=255

[PARENT] ========================================
[PARENT] ✅✅✅ 验证成功！ ✅✅✅
[PARENT] ========================================
[PARENT] Windows Named Shared Resource 工作正常
[PARENT] ✅ 可以进入 Phase 2: Windows 实施
[PARENT] ========================================
```

---

## 成功标准

✅ **验证成功**：
- 父进程创建纹理并设置为红色
- 子进程通过名称打开纹理并看到红色
- 子进程修改纹理为蓝色
- 父进程看到纹理变为蓝色

**结论**: Named Shared Resource 机制可行，可以用于 Flutter 跨进程零拷贝纹理共享。

---

## 故障排除

### 错误: "OpenSharedResourceByName 失败 (HRESULT=0x80070002)"

**原因**: Windows 版本不支持 named shared resource

**解决方案**:
- 确认 Windows 版本 ≥ Windows 8
- 如果是 Windows 7，需要降级使用 `D3D11_RESOURCE_MISC_SHARED_KEYEDMUTEX` + `OpenSharedResource`

### 错误: "D3D11CreateDevice 失败"

**原因**: GPU 不支持 D3D11

**解决方案**:
- 更新显卡驱动
- 确认显卡支持 DirectX 11

### 错误: "AcquireSync 超时"

**原因**: KeyedMutex 同步问题

**解决方案**:
- 确认父子进程都正确使用 AcquireSync/ReleaseSync
- 检查 key 值匹配 (父进程用 0→1, 子进程用 1→2, 父进程用 2→0)

---

## 技术细节

### Named Shared Resource vs HANDLE 值传递

| 方案 | 优点 | 缺点 |
|------|------|------|
| **Named Handle** (本 demo) | • 跨进程简单<br>• 不需要 DuplicateHandle<br>• 类似 IOSurface 全局命名 | • 需要 Windows 8+ |
| HANDLE 值传递 | • Windows 7 支持 | • 需要 DuplicateHandle<br>• 句柄值在不同进程可能不同 |

**结论**: Named Shared Resource 是更简单可靠的方案。

### KeyedMutex 同步机制

```
父进程              Key      子进程
────────────────────────────────────
AcquireSync(0)      0
写入红色
ReleaseSync(1)      1  →    AcquireSync(1)
                            读取红色 ✅
                            写入蓝色
                    2  ←    ReleaseSync(2)
AcquireSync(2)      2
读取蓝色 ✅
ReleaseSync(0)      0
```

每次 `ReleaseSync(N)` 将 key 设为 N，下一个 `AcquireSync(N)` 等待 key == N。

---

## 下一步

✅ 验证成功 → 进入 **Phase 2: Windows 实施**

- 在 Flutter Plugin 中实现 named shared resource 创建
- 实现 `FlutterDesktopGpuSurfaceCallback`
- 修改 `cube_renderer` 的 Windows 版本使用 `OpenSharedResourceByName`
