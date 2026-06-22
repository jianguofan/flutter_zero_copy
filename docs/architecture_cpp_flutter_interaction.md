# C++ ↔ Flutter 零拷贝纹理交互架构

```mermaid
flowchart TB
    subgraph FlutterProcess["🖥️ Flutter 主进程"]
        direction TB

        subgraph DartLayer["🎯 Dart 层"]
            ZCW["ZeroCopyWidget (StatefulWidget)"]
            MC["MethodChannel<br/>'com.snapmaker.zero_copy/texture'"]
            TW["Texture(textureId)<br/>└─ 只占一个 Rect 位置<br/>└─ 不持有像素数据"]
            ZCW -->|"invokeMethod('createSurface')"| MC
            ZCW -->|"build() → Positioned+SizedBox"| TW
        end

        subgraph SwiftPlugin["🍎 Native Plugin (Swift)"]
            SP["ZeroCopyTexturePlugin"]
            TR["FlutterTextureRegistry"]
            IOS["IOSurfaceCreate()<br/>└─ kIOSurfaceIsGlobal: true"]
            CV["CVPixelBufferCreateWithIOSurface()<br/>└─ 零拷贝包装"]
            CVL["CVDisplayLink<br/>└─ 硬件 vsync 回调 (60Hz)"]
            RT["registerTexture(textureId)"]

            MC -->|"MethodCall"| SP
            SP -->|"1. IOSurfaceCreate(w, h)"| IOS
            IOS -->|"2. surfaceID (uint32)"| SP
            IOS -->|"3. CVPixelBufferCreate"| CV
            SP -->|"4. register(self)"| TR
            TR -->|"5. textureId (Int64)"| RT
            CVL -->|"onDisplayLink()"| TR
            TR -->|"textureFrameAvailable(id)"| TW
        end
    end

    subgraph ChildProcess["⚙️ C++ 子进程 (cube_renderer)"]
        direction TB
        MAIN["main(argc, argv)<br/>接收 surfaceID(width, height)"]
        CTX["CGL 创建 Headless Context<br/>└─ NULL = 无窗口<br/>└─ Core Profile 3.2"]
        LOOKUP["IOSurfaceLookup(surfaceID)<br/>└─ 按 ID 查找共享 GPU 内存"]
        GLTEX["CGLTexImageIOSurface2D()<br/>└─ GL_TEXTURE_RECTANGLE<br/>└─ 绑定到 IOSurface (零拷贝!)"]
        FBO["glGenFramebuffers + glGenRenderbuffers<br/>└─ IOSurface = color attachment 0<br/>└─ depth buffer 独立分配"]
        LOOP["渲染循环 (~60fps)"]
        DRAW["glClear → computeMVP → glDrawArrays → glFlush<br/>└─ glFlush 更新 IOSurface seed"]

        MAIN --> CTX --> LOOKUP --> GLTEX --> FBO --> LOOP
        LOOP -->|"每帧"| DRAW
        DRAW -->|"glFlush → seed++"| IOS
    end

    subgraph GPU["🎮 GPU VRAM (同一块物理内存)"]
        IOSURF["IOSurface<br/>└─ BGRA8 · 800×600 · 1.92MB<br/>└─ seed 原子操作同步"]
        METAL["Metal 纹理<br/>(Impeller 读取)"]
        GL["OpenGL GL 纹理<br/>(glDrawArrays 写入)"]
        IOSURF <-...->|"零拷贝 — 同一个 IOSurface"| METAL
        IOSURF <-...->|"零拷贝 — 同一个 IOSurface"| GL
    end

    TW -.->|"Impeller 采样"| METAL
    GL -.->|"FBO 渲染到"| IOSURF
    IOS -->|"surfaceID<br/>通过命令行参数传递"| LOOKUP
    CV -.->|"CVPixelBuffer<br/>绑定到同一块"| IOSURF
    TR -.->|"textureFrameAvailable<br/>通知 Flutter 刷新"| TW

    style FlutterProcess fill:#e3f2fd,stroke:#1565c0
    style ChildProcess fill:#fff3e0,stroke:#ef6c00
    style GPU fill:#e8f5e9,stroke:#2e7d32
    style DartLayer fill:#bbdefb,stroke:#1976d2
    style SwiftPlugin fill:#c8e6c9,stroke:#388e3c
```

## 关键交互时序

```mermaid
sequenceDiagram
    participant Dart as 🎯 Dart (ZeroCopyWidget)
    participant Swift as 🍎 Swift Plugin
    participant GPU as 🎮 GPU VRAM (IOSurface)
    participant CXX as ⚙️ C++ (cube_renderer)
    participant Impeller as 🖼️ Impeller (Flutter Engine)

    Note over Dart,Impeller: ── 初始化阶段 ──

    Dart->>Swift: invokeMethod('createSurface', {w, h})
    Swift->>GPU: IOSurfaceCreate(w, h, BGRA8, kIOSurfaceIsGlobal)
    GPU-->>Swift: surfaceRef + surfaceID
    Swift->>GPU: CVPixelBufferCreateWithIOSurface(surfaceRef)
    Swift->>Swift: textureId = registerTexture()
    Swift-->>Dart: { surfaceID, textureId }

    Dart->>CXX: Process.start('cube_renderer', [surfaceID, w, h])
    CXX->>GPU: IOSurfaceLookup(surfaceID)
    CXX->>CXX: CGLTexImageIOSurface2D → GL texture
    CXX->>CXX: FBO color attachment = GL texture

    Note over Dart,Impeller: ── 每帧循环 ──

    loop 60fps (CVDisplayLink 硬件 vsync)
        CXX->>GPU: glClear + glDrawArrays + glFlush
        Note over GPU: IOSurface seed 原子递增

        Swift->>Swift: onDisplayLink() callback
        Swift->>Impeller: textureFrameAvailable(textureId)
        Impeller->>GPU: 采样 Metal 纹理 (零拷贝)
        Impeller->>Dart: 合成到 Texture widget 位置

        Note over CXX: usleep(16667) ≈ 60fps
    end

    Note over Dart,Impeller: ── 销毁阶段 ──

    Dart->>CXX: kill(SIGTERM)
    Dart->>Swift: invokeMethod('dispose')
    Swift->>Swift: CVDisplayLinkStop
    Swift->>Swift: unregisterTexture(textureId)
    Swift->>GPU: IOSurface 引用计数 -1 → 释放
```

## 核心设计原则

| 原则 | 说明 |
|------|------|
| **Flutter 只提供纹理位置** | `Texture(textureId)` widget 只占一个 `Rect`，不持有任何像素数据。渲染完全由 C++ 进程在 GPU 上完成 |
| **零拷贝** | IOSurface 在同一块 GPU VRAM 上，Metal 和 OpenGL 直接读写，无 CPU 拷贝 |
| **跨进程共享** | `surfaceID` (32-bit 整数) 通过命令行参数传递，C++ 进程用 `IOSurfaceLookup(id)` 查找 |
| **硬件 vsync 同步** | CVDisplayLink 注册在硬件刷新回调上，而非 Dart Ticker，延迟最低 |
| **种子同步** | `glFlush()` 原子递增 IOSurface seed，Impeller 检测到 seed 变化后重新采样 |

---

## 简化版：用户视角流程

```mermaid
flowchart TD
    User(("👤 用户"))

    User -->|"① 选择 .3mf 文件"| Studio["🖥️ Orca Studio (Flutter)"]

    subgraph Studio["Orca Studio"]
        direction TB
        TexBox["📦 纹理框 (Texture widget)<br/>────────<br/>只占一个 Rect 位置<br/>像素由外部进程渲染"]
        Btn["🔪 切片按钮"]
    end

    Studio -->|"② Process.start()<br/>传递 surfaceID"| Child["⚙️ orca-slice-engine (C++ 子进程)"]

    subgraph Child["orca-slice-engine"]
        direction LR
        Render["🎨 渲染模式<br/>────────<br/>OpenGL → IOSurface<br/>3D 模型实时预览<br/>旋转/缩放/平移"]
        Slice["🔪 切片模式<br/>────────<br/>3MF → GCode<br/>libslic3r 管线<br/>输出 .gcode 文件"]
    end

    Child -->|"IOSurface 零拷贝<br/>GPU VRAM 共享"| TexBox
    Btn -->|"③ 点击切片<br/>MethodChannel 通知"| Child
    Render -.->|"切换模式"| Slice
    Slice -->|"④ 进度回调"| Studio
    Slice -->|"输出"| FS[("💾 文件系统<br/>output.gcode")]
```

> **关键点**：C++ 子进程是一个独立可执行文件，Flutter 通过 `Process.start()` 启动它。同一个进程负责两件事：空闲时渲染 3D 预览（通过 IOSurface 零拷贝到 Flutter 的 Texture widget）、收到切片指令后切换到切片模式（3MF → GCode）。进程间只传递 surfaceID（32-bit 整数）和命令（切片/暂停/取消）。
