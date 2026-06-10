# 3D 交互 — 手动旋转与缩放

> 为 cube_renderer 添加鼠标/触控交互，支持手动旋转、缩放和重

置

---

## 1. 架构

```
Dart (Flutter)                          C++ (cube_renderer)
═══════════                             ═══════════════════

Listener.onPointerMove                  readStdinNonBlocking()
  → deltaX, deltaY                       → 解析 JSON
                                         → camera.rotate(dx, dy)
JSON: {"type":"rotate",                  → arcball 四元数累积
       "dx":2.3, "dy":-1.1}
       │                                  computeMVP(rot, zoom)
       │ stdin (非阻塞)                     │
       └─────────────────────────────────→│
                                          glUniformMatrix4fv(uMVP, ...)
Listener.onPointerSignal                 glDrawArrays(...)
  → scrollDelta

JSON: {"type":"zoom",
       "scale":1.2}

双击 → {"type":"reset"}
```

### 两个核心组件

| 组件 | 语言 | 职责 |
|------|------|------|
| ZeroCopyWidget (扩展) | Dart | 在 Texture 上叠 Listener，捕获原始手势 delta，拼 JSON 写 stdin |
| Camera + stdin 处理器 | C++ | 非阻塞读取 stdin，解析命令，维护 camera 状态，arcball 旋转 |

---

## 2. Dart 侧

### 2.1 Widget API

在现有 `ZeroCopyWidget` 上添加交互参数，**向后兼容**：

```dart
ZeroCopyWidget({
  // 现有参数 (不变)
  required double width,
  required double height,
  required double left,
  required double top,
  String? rendererPath,
  bool debugCpp = false,

  // 新增:
  bool interactive = true,       // 是否允许手动旋转/缩放
  bool autoRotate = false,       // 初始是否自动旋转
  double rotationSpeed = 0.005,  // 拖拽灵敏度
  double zoomSpeed = 0.001,      // 滚轮灵敏度
  double minZoom = 1.5,          // 最近距离 (camera near limit)
  double maxZoom = 20.0,         // 最远距离 (camera far limit)
})
```

### 2.2 Listener 层

```dart
Stack(
  children: [
    // Layer 0: 3D 纹理
    Texture(textureId: _textureId!),

    // Layer 1: 透明触摸层
    Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerSignal: _handleScroll,
      child: Container(color: Colors.transparent),
    ),

    // Layer 2: 信息 overlay
    Positioned(...),
  ],
)
```

- `HitTestBehavior.opaque` 确保捕获所有触摸事件
- `onPointerSignal` 是滚轮事件入口（Flutter 自动路由鼠标滚轮到正确的 widget）
- `onPointerMove` 携带 `delta`（前后两帧的位移差），直接用于 arcball

### 2.3 事件处理逻辑

```dart
void _handlePointerMove(PointerMoveEvent e) {
  if (!interactive || !_ready) return;
  final json = '{"type":"rotate","dx":${e.delta.dx},"dy":${e.delta.dy}}\n';
  _childProcess!.stdin.write(json);  // 非字符串编码，直接写字节
}

void _handleScroll(PointerSignalEvent e) {
  if (e is PointerScrollEvent && !_ready) return;
  final scale = e.scrollDelta.dy;  // macOS: 正值=向上滚=放大
  final json = '{"type":"zoom","scale":$scale}\n';
  _childProcess!.stdin.write(json);
}

void _handleDoubleTap() {
  _childProcess!.stdin.write('{"type":"reset"}\n');
}
```

### 2.4 stdin 写入方式

**注意**: Dart `Process.stdin` 默认使用 `UTF-8` 编码。直接 `write(jsonString)` 即可，无需 `writeln`（避免 flush 延迟）。每条命令后加 `\n` 作为分隔符。

---

## 3. C++ 侧

### 3.1 Camera 状态

```cpp
struct Camera {
    float rotationX = 0.0f;   // 绕 X 轴角度 (rad)
    float rotationY = 0.0f;   // 绕 Y 轴角度 (rad)
    float zoom = 6.0f;        // camera distance from origin
    float minZoom = 1.5f;
    float maxZoom = 20.0f;
    float sensitivity = 0.005f;
    bool  autoRotate = false;
    float autoRotateTimer = 2.0f;  // 无操作后自动恢复

    void rotate(float dx, float dy);
    void zoom(float scaleDelta);
    void reset();
};
```

### 3.2 非阻塞 stdin

```cpp
// 初始化
fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);

// 渲染循环中
std::string stdinBuf;
void readCommands() {
    char buf[256];
    while (true) {
        ssize_t n = read(STDIN_FILENO, buf, sizeof(buf) - 1);
        if (n <= 0) break;  // EAGAIN
        stdinBuf.append(buf, n);
    }
    size_t nl;
    while ((nl = stdinBuf.find('\n')) != std::string::npos) {
        handleCommand(stdinBuf.substr(0, nl));
        stdinBuf.erase(0, nl + 1);
    }
}
```

### 3.3 JSON 解析 (轻量级)

只支持三种命令，手动字符串匹配，不引入库：

```cpp
void handleCommand(const std::string& line) {
    if (line.find("\"rotate\"") != std::string::npos) {
        float dx = extractFloat(line, "dx");
        float dy = extractFloat(line, "dy");
        camera.rotate(dx, dy);
        camera.autoRotateTimer = 2.0f;  // 用户操作=暂停自动旋转
    } else if (line.find("\"zoom\"") != std::string::npos) {
        float s = extractFloat(line, "scale");
        camera.zoom(s);
        camera.autoRotateTimer = 2.0f;
    } else if (line.find("\"reset\"") != std::string::npos) {
        camera.reset();
    }
}

// 辅助: 从 JSON 中提取 "key":value
float extractFloat(const std::string& s, const char* key);
```

### 3.4 Arcball 旋转

```cpp
struct Quat { float w, x, y, z; };
Quat cameraQuat = {1, 0, 0, 0};  // 单位四元数 (初始无旋转)

// 屏幕坐标 → 单位半球上的 3D 点
vec3 screenToSphere(float sx, float sy, float radius) {
    float x =  sx / radius;
    float y = -sy / radius;  // Y 翻转 (屏幕坐标系 Y 朝下)
    float z2 = 1.0f - x*x - y*y;
    float z = z2 > 0 ? sqrtf(z2) : 0.0f;
    float len = sqrtf(x*x + y*y + z*z);
    return {x / len, y / len, z / len};
}

// 两个球面点之间的旋转四元数
Quat rotationBetween(vec3 from, vec3 to) {
    vec3 axis = cross(from, to);
    float dot = clamp(dot(from, to), -1.0f, 1.0f);
    // 如果两点非常接近 (dot ≈ 1)，angle ≈ 0，跳过
    if (dot > 0.9999f) return {1, 0, 0, 0};
    float angle = acosf(dot);
    float s = sinf(angle * 0.5f);
    float len = sqrtf(axis.x*axis.x + axis.y*axis.y + axis.z*axis.z);
    return {cosf(angle*0.5f), axis.x*s/len, axis.y*s/len, axis.z*s/len};
}

// 四元数转 4x4 旋转矩阵 (列主序)
void quatToMatrix(const Quat& q, float* m);
```

### 3.5 computeMVP 改造

```cpp
void computeMVP(float* mvp, const Camera& cam, int width, int height) {
    float aspect = (float)width / (float)height;

    // Projection matrix (不变)
    float proj[16] = { /* ... same as before ... */ };

    // View: camera at distance zoom from origin
    float view[16] = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, -cam.zoom, 1
    };

    // Model: arcball quaternion → matrix
    float model[16];
    quatToMatrix(cam.cameraQuat, model);

    // MVP = proj * view * model
    float viewModel[16];
    mul(view, model, viewModel);
    mul(proj, viewModel, mvp);
}
```

### 3.6 自动旋转

渲染循环中每帧递减 `autoRotateTimer`。当 timer > 0 时暂停自动旋转；timer 归零后恢复：

```cpp
// 每帧:
float dt = 0.0167f;  // ~60fps
if (cam.autoRotate && cam.autoRotateTimer <= 0) {
    cam.rotate(0.02f, 0);  // 绕 Y 轴缓慢旋转
}
cam.autoRotateTimer = max(0, cam.autoRotateTimer - dt);
```

---

## 4. 命令协议

JSON Lines (一条命令 = 一行 JSON)：

| 命令 | JSON | 触发条件 | C++ 动作 |
|------|------|---------|---------|
| `rotate` | `{"type":"rotate","dx":2.3,"dy":-1.1}` | 单指/鼠标拖动 | arcball 累积旋转 |
| `zoom` | `{"type":"zoom","scale":1.2}` | 滚轮/双指捏合 | camera.zoom 调整距离 |
| `reset` | `{"type":"reset"}` | 双击 | 重置四元数和 zoom |

---

## 5. 跨平台考虑

### stdin 非阻塞

| 平台 | 实现 |
|------|------|
| macOS | `fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK)` + `read()` |
| Windows | `PeekNamedPipe` 轮询 + `ReadFile` |

### 编译宏隔离

```cpp
#ifdef _WIN32
  // Windows: PeekNamedPipe
#else
  // POSIX: fcntl + read
#endif
```

### Listener 事件

- **macOS Trackpad**: `PointerMoveEvent.delta` 已经是增量，精度足够
- **Windows 鼠标**: `PointerMoveEvent.delta` 同样可用
- **滚轮**: 两边都通过 `PointerScrollEvent` 到达

---

## 6. 改动文件清单

| 文件 | 改动类型 | 说明 |
|------|---------|------|
| `lib/main.dart` | 修改 | ZeroCopyWidget 添加 Listener、stdin 写入、交互参数 |
| `cube_renderer/main.cpp` | 修改 | 添加 Camera、非阻塞 stdin、arcball 数学、自动旋转计时 |
| `docs/IMPLEMENTATION.md` | 更新 | 补充交互设计文档 |

---

## 7. 不实现（YAGNI）

- ❌ 键盘快捷键控制旋转
- ❌ 保存/恢复视角预设
- ❌ 双指平移 (pan)
- ❌ 动画补间 (tween to reset)
- ❌ Android/iOS 触控（仅 macOS + 未来 Windows）
