# 3D Interaction — Arcball Rotation & Zoom

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add manual arcball rotation, scroll zoom, and double-tap reset to the cube renderer via Dart Listener + stdin pipe.

**Architecture:** Dart captures raw pointer deltas via Listener widget overlaid on Texture, writes JSON commands to C++ child process stdin. C++ reads stdin non-blocking each frame, accumulates arcball quaternion and zoom, feeds into existing computeMVP pipeline.

**Tech Stack:** Flutter (Dart), C++17, OpenGL 3.3 Core, macOS (POSIX)

---

## File Structure

| File | Role |
|------|------|
| `cube_renderer/main.cpp` | C++ renderer — arcball math, Camera state, non-blocking stdin reader, render loop |
| `lib/main.dart` | Flutter app — Listener overlay, stdin writer, interactive params, demo UI |

All changes in two files only.

---

## Task Order Rationale

**C++ first, Dart second.** The C++ side can be built and tested independently (launch cube_renderer manually, pipe commands via `echo | ./cube_renderer`). Once C++ is verified, Dart integration is a thin layer on top.

---

### Task 1: C++ — Add math primitives (vec3, Quat, arcball functions)

**Files:**
- Modify: `cube_renderer/main.cpp`

- [ ] **Step 1: Add vec3 and Quat structs after the global state section (after line 119)**

```cpp
// ---------------------------------------------------------------------------
// Math primitives for arcball
// ---------------------------------------------------------------------------

struct vec3 {
    float x, y, z;
    vec3() : x(0), y(0), z(0) {}
    vec3(float x_, float y_, float z_) : x(x_), y(y_), z(z_) {}
};

static vec3 cross(const vec3& a, const vec3& b) {
    return vec3(a.y * b.z - a.z * b.y,
                a.z * b.x - a.x * b.z,
                a.x * b.y - a.y * b.x);
}

static float dot(const vec3& a, const vec3& b) {
    return a.x * b.x + a.y * b.y + a.z * b.z;
}

static float clamp(float v, float lo, float hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

struct Quat {
    float w, x, y, z;
    Quat() : w(1), x(0), y(0), z(0) {}  // identity
    Quat(float w_, float x_, float y_, float z_) : w(w_), x(x_), y(y_), z(z_) {}
};

// Screen coords → point on unit hemisphere (arcball projection)
static vec3 screenToSphere(float sx, float sy, float radius) {
    float x =  sx / radius;
    float y = -sy / radius;  // Y flip: screen Y is down, GL Y is up
    float z2 = 1.0f - x * x - y * y;
    float z = z2 > 0.0f ? sqrtf(z2) : 0.0f;
    // Normalize to unit sphere surface
    // When outside the sphere (z==0), project to equator ring
    float len = sqrtf(x * x + y * y + z * z);
    if (len < 0.0001f) return vec3(0, 0, 1);
    return vec3(x / len, y / len, z / len);
}

// Quaternion representing rotation from vector 'from' to vector 'to'
static Quat rotationBetween(const vec3& from, const vec3& to) {
    float d = clamp(dot(from, to), -1.0f, 1.0f);
    // Vectors nearly parallel → identity quaternion
    if (d > 0.9999f) return Quat(1, 0, 0, 0);
    // Vectors nearly opposite → 180° around arbitrary perpendicular axis
    if (d < -0.9999f) {
        vec3 axis = cross(vec3(1, 0, 0), from);
        float axLen = sqrtf(dot(axis, axis));
        if (axLen < 0.0001f) axis = cross(vec3(0, 1, 0), from);
        axLen = sqrtf(dot(axis, axis));
        return Quat(0, axis.x / axLen, axis.y / axLen, axis.z / axLen);
    }
    vec3 axis = cross(from, to);
    float angle = acosf(d);
    float s = sinf(angle * 0.5f);
    float axLen = sqrtf(dot(axis, axis));
    return Quat(cosf(angle * 0.5f),
                axis.x * s / axLen,
                axis.y * s / axLen,
                axis.z * s / axLen);
}

// Multiply two quaternions: q = a * b
static Quat quatMul(const Quat& a, const Quat& b) {
    return Quat(
        a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
        a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w
    );
}

// Quaternion → 4x4 column-major rotation matrix
static void quatToMatrix(const Quat& q, float* m) {
    float xx = q.x * q.x, yy = q.y * q.y, zz = q.z * q.z;
    float xy = q.x * q.y, xz = q.x * q.z, yz = q.y * q.z;
    float wx = q.w * q.x, wy = q.w * q.y, wz = q.w * q.z;

    m[0]  = 1.0f - 2.0f * (yy + zz);
    m[1]  = 2.0f * (xy + wz);
    m[2]  = 2.0f * (xz - wy);
    m[3]  = 0.0f;

    m[4]  = 2.0f * (xy - wz);
    m[5]  = 1.0f - 2.0f * (xx + zz);
    m[6]  = 2.0f * (yz + wx);
    m[7]  = 0.0f;

    m[8]  = 2.0f * (xz + wy);
    m[9]  = 2.0f * (yz - wx);
    m[10] = 1.0f - 2.0f * (xx + yy);
    m[11] = 0.0f;

    m[12] = 0.0f;
    m[13] = 0.0f;
    m[14] = 0.0f;
    m[15] = 1.0f;
}
```

- [ ] **Step 2: Build and verify compilation**

Run: `bash build_cube_renderer.sh`
Expected: BUILD SUCCESSFUL (no-op at runtime since nothing calls these yet)

- [ ] **Step 3: Commit**

```bash
git add cube_renderer/main.cpp
git commit -m "feat: add vec3, Quat, arcball math primitives (screenToSphere, rotationBetween, quatToMatrix)"
```

---

### Task 2: C++ — Add Camera struct and update global state

**Files:**
- Modify: `cube_renderer/main.cpp`

- [ ] **Step 1: Add Camera struct after arcball math (after Quat functions)**

```cpp
// ---------------------------------------------------------------------------
// Camera state (controlled via stdin commands)
// ---------------------------------------------------------------------------

struct Camera {
    Quat   orientation = Quat();  // identity = no rotation
    float  zoom        = 6.0f;
    float  minZoom     = 1.5f;
    float  maxZoom     = 20.0f;
    float  sensitivity = 0.005f;
    bool   autoRotate  = false;
    float  autoRotateAngle = 0.0f;    // accumulated auto-rotation angle
    float  idleTimer       = 2.0f;    // seconds since last user input

    void rotate(float dx, float dy) {
        // Build arcball: track mouse delta as movement on the unit sphere
        float radius = 300.0f;  // arcball radius in pixels (matches typical widget size)
        vec3 from = screenToSphere(0, 0, radius);
        vec3 to   = screenToSphere(dx * sensitivity * 100.0f,
                                    dy * sensitivity * 100.0f, radius);
        Quat delta = rotationBetween(from, to);
        orientation = quatMul(delta, orientation);  // pre-multiply: delta * current
        idleTimer = 2.0f;  // reset auto-rotation timer
    }

    void zoomBy(float delta) {
        zoom -= delta * 0.01f;  // scale arbitrary: 1 wheel tick ≈ 0.01 distance
        if (zoom < minZoom) zoom = minZoom;
        if (zoom > maxZoom) zoom = maxZoom;
        idleTimer = 2.0f;
    }

    void reset() {
        orientation = Quat();  // identity
        zoom = 6.0f;
        autoRotateAngle = 0.0f;
        idleTimer = 2.0f;
    }
};
```

- [ ] **Step 2: Add Camera instance to global state (after existing globals at line 118)**

```cpp
static Camera g_camera;
```

- [ ] **Step 3: Build and verify**

Run: `bash build_cube_renderer.sh`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add cube_renderer/main.cpp
git commit -m "feat: add Camera struct with arcball rotate/zoom/reset methods"
```

---

### Task 3: C++ — Add non-blocking stdin reader and JSON command parser

**Files:**
- Modify: `cube_renderer/main.cpp`

- [ ] **Step 1: Add includes at top of file (after line 25)**

```cpp
#include <fcntl.h>
#include <string>
```

- [ ] **Step 2: Add stdin buffer (global) and readCommands/parse functions after Camera struct (after Task 2 additions)**

```cpp
// ---------------------------------------------------------------------------
// Non-blocking stdin reader (receives JSON commands from Flutter)
// ---------------------------------------------------------------------------

static std::string g_stdinBuf;

// Extract float value for a given JSON key.  Input example: "dx":2.3
// Returns 0.0f if key not found.
static float extractFloat(const std::string& s, const char* key) {
    // Search for "key":
    std::string search = "\"";
    search += key;
    search += "\":";
    size_t pos = s.find(search);
    if (pos == std::string::npos) return 0.0f;
    pos += search.length();
    // Skip optional whitespace
    while (pos < s.size() && (s[pos] == ' ' || s[pos] == '\t')) pos++;
    // Parse float: handle optional '-' sign, digits, '.', 'e', 'E', '+'
    char* end = nullptr;
    float val = strtof(s.c_str() + pos, &end);
    (void)end;  // unused
    return val;
}

static void handleCommand(const std::string& line, Camera& cam) {
    if (line.find("\"rotate\"") != std::string::npos) {
        float dx = extractFloat(line, "dx");
        float dy = extractFloat(line, "dy");
        cam.rotate(dx, dy);
        printf("[cube_renderer] rotate dx=%.2f dy=%.2f\n", dx, dy);
    } else if (line.find("\"zoom\"") != std::string::npos) {
        float scale = extractFloat(line, "scale");
        cam.zoomBy(scale);
        printf("[cube_renderer] zoom scale=%.2f → zoom=%.2f\n", scale, cam.zoom);
    } else if (line.find("\"reset\"") != std::string::npos) {
        cam.reset();
        printf("[cube_renderer] reset\n");
    }
}

static void readCommands(Camera& cam) {
    char buf[256];
    while (true) {
        ssize_t n = read(STDIN_FILENO, buf, sizeof(buf) - 1);
        if (n <= 0) break;  // EAGAIN = no more data, or error
        g_stdinBuf.append(buf, (size_t)n);
    }
    // Process complete lines (delimited by '\n')
    size_t nl;
    while ((nl = g_stdinBuf.find('\n')) != std::string::npos) {
        std::string line = g_stdinBuf.substr(0, nl);
        g_stdinBuf.erase(0, nl + 1);
        if (!line.empty()) {
            handleCommand(line, cam);
        }
    }
}
```

- [ ] **Step 3: Build**

Run: `bash build_cube_renderer.sh`
Expected: BUILD SUCCESSFUL

- [ ] **Step 4: Commit**

```bash
git add cube_renderer/main.cpp
git commit -m "feat: add non-blocking stdin reader and JSON command parser"
```

---

### Task 4: C++ — Modify computeMVP to use Camera, update render loop

**Files:**
- Modify: `cube_renderer/main.cpp`

- [ ] **Step 1: Replace the existing `computeMVP` function (lines 196–241) with Camera-aware version**

Before edit, old function is around lines 196–241. Replace with:

```cpp
static void computeMVP(float* mvp, const Camera& cam, int width, int height) {
    float aspect = (float)width / (float)height;

    // Projection: perspective 45° FOV
    float fov = 45.0f * M_PI / 180.0f;
    float near = 0.1f, far = 100.0f;
    float f = 1.0f / tanf(fov / 2.0f);

    float proj[16] = {
        f / aspect, 0, 0, 0,
        0, f, 0, 0,
        0, 0, (far + near) / (near - far), -1,
        0, 0, (2 * far * near) / (near - far), 0
    };

    // View: camera at distance zoom from origin, looking at (0,0,0)
    float view[16] = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, -cam.zoom, 1
    };

    // Model: arcball quaternion → rotation matrix
    float model[16];
    quatToMatrix(cam.orientation, model);

    // Column-major multiply: out = a * b
    auto mul = [](const float* a, const float* b, float* out) {
        for (int i = 0; i < 16; i++) out[i] = 0;
        for (int col = 0; col < 4; col++)
            for (int row = 0; row < 4; row++)
                for (int k = 0; k < 4; k++)
                    out[col * 4 + row] += a[k * 4 + row] * b[col * 4 + k];
    };

    // MVP = proj * view * model
    float viewModel[16];
    mul(view, model, viewModel);
    mul(proj, viewModel, mvp);
}
```

- [ ] **Step 2: In the render loop (around line 502), add stdin read and auto-rotation logic. Find the `while (g_running) {` block and add at the top:**

```cpp
while (g_running) {
    // ── Process commands from Flutter ──
    readCommands(g_camera);

    // ── Auto-rotation timer ──
    float dt = 0.0167f;
    if (g_camera.idleTimer > 0.0f) {
        g_camera.idleTimer -= dt;
        if (g_camera.idleTimer < 0.0f) g_camera.idleTimer = 0.0f;
    }
    if (g_camera.autoRotate && g_camera.idleTimer <= 0.0f) {
        g_camera.autoRotateAngle += 0.02f;
        // Slow auto-rotation around Y axis: use arcball to rotate by delta
        // Simpler: directly add to autoRotateAngle and apply extra Y rotation
    }

    glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
    glViewport(0, 0, surfW, surfH);
```

- [ ] **Step 3: Replace the `computeMVP(mvp, angle, surfW, surfH)` call in render loop with Camera version**

Find the call `computeMVP(mvp, angle, surfW, surfH)` (around line 516) and replace:

```cpp
        // Apply auto-rotation as extra Y-axis rotation on top of arcball orientation
        Camera frameCam = g_camera;
        if (g_camera.autoRotate && g_camera.idleTimer <= 0.0f) {
            // Add auto-rotation as a slight Y-axis delta each frame
            Quat autoY(vec3(0, 1, 0), 0.02f);  // We need a helper: quat from axis-angle
        }
        computeMVP(mvp, g_camera, surfW, surfH);
```

Wait — we need a helper to build a quat from axis-angle for auto-rotation. Let me provide a better approach: pre-compute the combined model matrix.

Replace the `computeMVP` call and surrounding block (around lines 498–541) with this complete render loop:

- [ ] **Step 3 (revised): Replace the entire render loop section (from `float angle = 0.0f;` through the end of the while loop body) with Camera-aware version**

Find in main():
```cpp
    float angle = 0.0f;
    const float anglePerFrame = 0.02f;
    int frameCount = 0;

    while (g_running) {
```

Replace from `float angle = 0.0f;` through the end of the while loop (ending before cleanup) with:

```cpp
    int frameCount = 0;

    while (g_running) {
        // ── Process stdin commands ──────────────────────────────────
        readCommands(g_camera);

        // ── Update auto-rotation timer ─────────────────────────────
        float dt = 0.0167f;
        if (g_camera.idleTimer > 0.0f) {
            g_camera.idleTimer -= dt;
            if (g_camera.idleTimer < 0.0f) g_camera.idleTimer = 0.0f;
        }

        glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
        glViewport(0, 0, surfW, surfH);

        // Alternate clear color for visibility
        if ((frameCount / 30) % 2 == 0) {
            glClearColor(0.3f, 0.15f, 0.15f, 1.0f);
        } else {
            glClearColor(0.15f, 0.15f, 0.35f, 1.0f);
        }
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);

        // Build a temporary camera that includes auto-rotation
        Camera frameCam = g_camera;
        if (g_camera.autoRotate && g_camera.idleTimer <= 0.0f) {
            // Increment auto-rotation angle and build Y-axis rotation quat
            g_camera.autoRotateAngle += 0.02f;
            float halfA = g_camera.autoRotateAngle * 0.5f;
            Quat autoY(cosf(halfA), 0.0f, sinf(halfA), 0.0f);
            frameCam.orientation = quatMul(autoY, g_camera.orientation);
        }

        float mvp[16];
        computeMVP(mvp, frameCam, surfW, surfH);

        // Debug: print every 60 frames
        if (frameCount % 60 == 0) {
            printf("[cube_renderer] Frame %d, zoom=%.2f, idleTimer=%.2f\n",
                   frameCount, g_camera.zoom, g_camera.idleTimer);
            printf("  MVP row0: [%.3f, %.3f, %.3f, %.3f]\n", mvp[0], mvp[4], mvp[8], mvp[12]);
            printf("  MVP row1: [%.3f, %.3f, %.3f, %.3f]\n", mvp[1], mvp[5], mvp[9], mvp[13]);
            printf("  MVP row2: [%.3f, %.3f, %.3f, %.3f]\n", mvp[2], mvp[6], mvp[10], mvp[14]);
            printf("  MVP row3: [%.3f, %.3f, %.3f, %.3f]\n", mvp[3], mvp[7], mvp[11], mvp[15]);
        }

        glUseProgram(g_program);
        glUniformMatrix4fv(uMVPLoc, 1, GL_FALSE, mvp);

        glBindVertexArray(g_vao);
        glDrawArrays(GL_TRIANGLES, 0, 36);
        glBindVertexArray(0);
        glUseProgram(0);

        if (frameCount % 60 == 0) {
            GLenum glErr = glGetError();
            if (glErr != GL_NO_ERROR) {
                fprintf(stderr, "[cube_renderer] GL Error: 0x%x at frame %d\n", glErr, frameCount);
            }
        }

        glFlush();
        frameCount++;
        usleep(16667);
    }
```

- [ ] **Step 4: In main(), set stdin non-blocking before the render loop. Add after IOSurface binding (around line 397):**

```cpp
    // ── Set stdin non-blocking for command reception ──────────────────
    fcntl(STDIN_FILENO, F_SETFL, O_NONBLOCK);
    printf("[cube_renderer] stdin set to non-blocking mode\n");
```

- [ ] **Step 5: Build**

Run: `bash build_cube_renderer.sh`
Expected: BUILD SUCCESSFUL

- [ ] **Step 6: Test manually — launch renderer and pipe a rotate command**

```bash
# In one terminal: create a test surface, launch renderer (or use Flutter app)
# In another terminal:
echo '{"type":"rotate","dx":10,"dy":0}' | /path/to/cube_renderer/build/cube_renderer <SURFACE_ID> 600 450
```

Expected: cube rotates (can verify via the Flutter app)

- [ ] **Step 7: Commit**

```bash
git add cube_renderer/main.cpp
git commit -m "feat: integrate Camera, stdin reader, and arcball into render loop"
```

---

### Task 5: Dart — Add interactive parameters and stdin writing to ZeroCopyWidget

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add import for `dart:convert` (already present at line 1 — verify)**

Check line 2: `import 'dart:convert';` — already present. No change needed.

- [ ] **Step 2: Add new fields to ZeroCopyWidget constructor (around lines 13–28)**

Replace the ZeroCopyWidget class definition (lines 13–28) with:

```dart
class ZeroCopyWidget extends StatefulWidget {
  final double width;
  final double height;
  final double left;
  final double top;
  final String? rendererPath;
  final bool debugCpp;

  // Interactive control parameters
  final bool interactive;
  final bool autoRotate;
  final double rotationSpeed;
  final double minZoom;
  final double maxZoom;

  const ZeroCopyWidget({
    super.key,
    required this.width,
    required this.height,
    required this.left,
    required this.top,
    this.rendererPath,
    this.debugCpp = false,
    this.interactive = true,
    this.autoRotate = false,
    this.rotationSpeed = 0.005,
    this.minZoom = 1.5,
    this.maxZoom = 20.0,
  });

  @override
  State<ZeroCopyWidget> createState() => _ZeroCopyWidgetState();
}
```

- [ ] **Step 3: Add stdin writing methods and pointer event handlers to state class**

Add these methods inside `_ZeroCopyWidgetState` (after `_launchRenderer` around line 113):

```dart
  // ── Interactive control ─────────────────────────────────────────────

  /// Write a JSON command to the child process stdin.
  void _sendCommand(Map<String, dynamic> cmd) {
    if (_childProcess == null) return;
    final json = '${jsonEncode(cmd)}\n';
    _childProcess!.stdin.write(json);
  }

  // Accumulated delta between sends
  double _accumulatedDx = 0.0;
  double _accumulatedDy = 0.0;
  int _lastSendTime = 0;

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.interactive) return;
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
    _lastSendTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.interactive) return;
    _accumulatedDx += e.delta.dx;
    _accumulatedDy += e.delta.dy;
    // Send at most once per ~16ms, with accumulated delta
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastSendTime < 16) return;
    _lastSendTime = now;
    _sendCommand({
      'type': 'rotate',
      'dx': _accumulatedDx * widget.rotationSpeed,
      'dy': _accumulatedDy * widget.rotationSpeed,
    });
    _accumulatedDx = 0.0;
    _accumulatedDy = 0.0;
  }

  void _onPointerUp(PointerUpEvent e) {
    // Flush any remaining delta
    if (_accumulatedDx != 0.0 || _accumulatedDy != 0.0) {
      _sendCommand({
        'type': 'rotate',
        'dx': _accumulatedDx * widget.rotationSpeed,
        'dy': _accumulatedDy * widget.rotationSpeed,
      });
      _accumulatedDx = 0.0;
      _accumulatedDy = 0.0;
    }
  }

  void _onPointerSignal(PointerSignalEvent e) {
    if (!widget.interactive) return;
    if (e is PointerScrollEvent) {
      _sendCommand({
        'type': 'zoom',
        'scale': e.scrollDelta.dy,
      });
    }
  }

  void _resetView() {
    _sendCommand({'type': 'reset'});
  }
```

- [ ] **Step 4: Replace the build() method (lines 116–164) to add Listener layer**

Replace the existing `build()` method:

```dart
  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_error != null) {
      child = Container(
        color: Colors.red.shade900,
        child: Center(
          child: Text('Error: $_error',
              style: const TextStyle(color: Colors.white, fontSize: 11)),
        ),
      );
    } else if (_initializing || _textureId == null) {
      child = Container(
        color: const Color(0xFF1A1A2E),
        child: const Center(child: CircularProgressIndicator(color: Colors.white54)),
      );
    } else {
      child = Texture(textureId: _textureId!);
    }

    return Positioned(
      left: widget.left,
      top: widget.top,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: Stack(
          children: [
            child,
            // Transparent touch layer for 3D interaction
            if (widget.interactive && _textureId != null && _error == null)
              Positioned.fill(
                child: GestureDetector(
                  onDoubleTap: _resetView,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _onPointerDown,
                    onPointerMove: _onPointerMove,
                    onPointerUp: _onPointerUp,
                    onPointerSignal: _onPointerSignal,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),
            if (_surfaceID != null)
              Positioned(
                left: 10, top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Cube | surfaceID=$_surfaceID | ${widget.width.toInt()}x${widget.height.toInt()}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 5: Pass interactive params when creating the child process (send initial config)**

After the C++ process starts and the surface is created, send the initial camera config. Add after line 97 in `_launchRenderer` (after `debugPrint('[ZeroCopy] Launching: $path $surfaceID');`):

```dart
    // Send initial camera config to C++ renderer
    _sendCommand({
      'type': 'config',
      'autoRotate': widget.autoRotate,
    });
```

Note: For now, C++ ignores unknown commands and autoRotate defaults to false. This is a forward-compatible hook.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add Listener overlay, stdin writer, and interactive params to ZeroCopyWidget"
```

---

### Task 6: Dart — Update demo app UI with interactive controls

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add `_autoRotate` field to `_ZeroCopyDemoAppState` (around line 189)**

Add after `bool _debugCpp = false;`:

```dart
  bool _autoRotate = false;
```

- [ ] **Step 2: Update the ZeroCopyWidget instantiation (around line 212) to pass interactive params**

Replace:
```dart
            if (_showCube)
              ZeroCopyWidget(
                key: ValueKey(_key),
                width: _width,
                height: _height,
                left: _left,
                top: _top,
                debugCpp: _debugCpp,
              ),
```

With:
```dart
            if (_showCube)
              ZeroCopyWidget(
                key: ValueKey(_key),
                width: _width,
                height: _height,
                left: _left,
                top: _top,
                debugCpp: _debugCpp,
                autoRotate: _autoRotate,
              ),
```

- [ ] **Step 3: Add autoRotate toggle and reset button to the control panel (inside `_controlPanel`, after the debug switch row around line 262)**

Add after the Debug C++ switch row:

```dart
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Auto Rotate', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const Spacer(),
              Switch(
                value: _autoRotate,
                activeColor: Colors.lightBlueAccent,
                onChanged: (v) => setState(() => _autoRotate = v),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () {
                // Re-create widget to trigger full init with new key
                setState(() { _key++; });
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset View', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              ),
            ),
          ),
```

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add autoRotate toggle and reset button to demo UI"
```

---

### Task 7: Build, run, and verify end-to-end

- [ ] **Step 1: Build C++ renderer**

Run: `bash build_cube_renderer.sh`
Expected: BUILD SUCCESSFUL, binary signed

- [ ] **Step 2: Run Flutter app in debug mode**

Run: `fvm flutter run -d macos`
Expected: App launches, cube renders

- [ ] **Step 3: Verify interactions**

Manual tests:
1. **Drag on cube area** → cube rotates (arcball)
2. **Scroll wheel on cube area** → cube zooms in/out
3. **Double-click on cube area** → cube resets to original view
4. **Toggle autoRotate switch** → cube auto-rotates (but stops during user interaction)
5. **Stop/Start button** → texture lifecycle works with new interactive layer

Check console output:
```
[cube_renderer] rotate dx=2.30 dy=-1.10
[cube_renderer] zoom scale=1.00 → zoom=5.99
[cube_renderer] reset
```

- [ ] **Step 4: Commit any final tweaks**

```bash
git add -A
git commit -m "chore: final verification — interactive 3D controls working"
```

---

## Verification Checklist

| # | Test | Expected |
|---|------|----------|
| 1 | Launch app | Cube renders, no errors |
| 2 | Drag mouse on cube | Cube rotates smoothly |
| 3 | Scroll wheel on cube | Cube zooms in/out |
| 4 | Double-click cube | Cube resets to original view |
| 5 | Toggle Auto Rotate ON | Cube rotates slowly around Y when idle |
| 6 | Drag while auto-rotating | Auto-rotation pauses during interaction, resumes after ~2s |
| 7 | Stop/Start toggle | Cube disappears/reappears, new surface created |
| 8 | Multi-finger drag (trackpad) | Arcball rotation works with multi-touch |
| 9 | Resize sliders (W/H) | Cube renders at new resolution |
| 10 | No GL errors in console | `glGetError()` returns `GL_NO_ERROR` |
