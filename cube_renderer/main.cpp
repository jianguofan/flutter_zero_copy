// cube_renderer — Headless OpenGL rotating cube rendered to IOSurface (zero-copy)
//
// Usage: ./cube_renderer <surfaceID> [width] [height]
//
// Architecture:
//   IOSurface (GPU VRAM shared with Flutter) → GL texture → FBO color attachment
//   Every frame: draw cube → glFlush → IOSurface seed updated → Flutter sees it
//
// Build: cd cube_renderer && mkdir build && cd build && cmake .. && make

#define GL_SILENCE_DEPRECATION
#include <OpenGL/gl3.h>
#include <OpenGL/gl3ext.h>
#include <OpenGL/CGLIOSurface.h>
#include <OpenGL/CGLCurrent.h>
#include <OpenGL/OpenGL.h>
#include <IOSurface/IOSurface.h>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#include <sys/types.h>
#include <sys/sysctl.h>

// ---------------------------------------------------------------------------
// Shaders (Core Profile 3.3)
// ---------------------------------------------------------------------------

static const char* vertexShaderSource = R"glsl(
#version 330 core
layout(location = 0) in vec3 aPos;
layout(location = 1) in vec3 aColor;

uniform mat4 uMVP;

out vec3 vColor;

void main() {
    gl_Position = uMVP * vec4(aPos, 1.0);
    vColor = aColor;
}
)glsl";

static const char* fragmentShaderSource = R"glsl(
#version 330 core
in vec3 vColor;
out vec4 fragColor;

void main() {
    fragColor = vec4(vColor, 1.0);
}
)glsl";

// ---------------------------------------------------------------------------
// Cube geometry: 36 vertices (12 triangles), each with position + color
// ---------------------------------------------------------------------------

struct Vertex {
    float x, y, z;
    float r, g, b;
};

static const Vertex cubeVertices[] = {
    // Front face (red)
    {-0.5f, -0.5f,  0.5f, 1.0f, 0.2f, 0.2f},
    { 0.5f, -0.5f,  0.5f, 1.0f, 0.2f, 0.2f},
    { 0.5f,  0.5f,  0.5f, 1.0f, 0.2f, 0.2f},
    {-0.5f, -0.5f,  0.5f, 1.0f, 0.2f, 0.2f},
    { 0.5f,  0.5f,  0.5f, 1.0f, 0.2f, 0.2f},
    {-0.5f,  0.5f,  0.5f, 1.0f, 0.2f, 0.2f},
    // Back face (blue)
    { 0.5f, -0.5f, -0.5f, 0.2f, 0.2f, 1.0f},
    {-0.5f, -0.5f, -0.5f, 0.2f, 0.2f, 1.0f},
    {-0.5f,  0.5f, -0.5f, 0.2f, 0.2f, 1.0f},
    { 0.5f, -0.5f, -0.5f, 0.2f, 0.2f, 1.0f},
    {-0.5f,  0.5f, -0.5f, 0.2f, 0.2f, 1.0f},
    { 0.5f,  0.5f, -0.5f, 0.2f, 0.2f, 1.0f},
    // Right face (green)
    { 0.5f, -0.5f,  0.5f, 0.2f, 0.8f, 0.2f},
    { 0.5f, -0.5f, -0.5f, 0.2f, 0.8f, 0.2f},
    { 0.5f,  0.5f, -0.5f, 0.2f, 0.8f, 0.2f},
    { 0.5f, -0.5f,  0.5f, 0.2f, 0.8f, 0.2f},
    { 0.5f,  0.5f, -0.5f, 0.2f, 0.8f, 0.2f},
    { 0.5f,  0.5f,  0.5f, 0.2f, 0.8f, 0.2f},
    // Left face (yellow)
    {-0.5f, -0.5f, -0.5f, 1.0f, 1.0f, 0.2f},
    {-0.5f, -0.5f,  0.5f, 1.0f, 1.0f, 0.2f},
    {-0.5f,  0.5f,  0.5f, 1.0f, 1.0f, 0.2f},
    {-0.5f, -0.5f, -0.5f, 1.0f, 1.0f, 0.2f},
    {-0.5f,  0.5f,  0.5f, 1.0f, 1.0f, 0.2f},
    {-0.5f,  0.5f, -0.5f, 1.0f, 1.0f, 0.2f},
    // Top face (cyan)
    {-0.5f,  0.5f,  0.5f, 0.2f, 1.0f, 1.0f},
    { 0.5f,  0.5f,  0.5f, 0.2f, 1.0f, 1.0f},
    { 0.5f,  0.5f, -0.5f, 0.2f, 1.0f, 1.0f},
    {-0.5f,  0.5f,  0.5f, 0.2f, 1.0f, 1.0f},
    { 0.5f,  0.5f, -0.5f, 0.2f, 1.0f, 1.0f},
    {-0.5f,  0.5f, -0.5f, 0.2f, 1.0f, 1.0f},
    // Bottom face (magenta)
    { 0.5f, -0.5f,  0.5f, 1.0f, 0.2f, 1.0f},
    {-0.5f, -0.5f,  0.5f, 1.0f, 0.2f, 1.0f},
    {-0.5f, -0.5f, -0.5f, 1.0f, 0.2f, 1.0f},
    { 0.5f, -0.5f,  0.5f, 1.0f, 0.2f, 1.0f},
    {-0.5f, -0.5f, -0.5f, 1.0f, 0.2f, 1.0f},
    { 0.5f, -0.5f, -0.5f, 1.0f, 0.2f, 1.0f},
};

// ---------------------------------------------------------------------------
// Global state (for signal handler cleanup)
// ---------------------------------------------------------------------------

static volatile bool g_running = true;
static GLuint g_vao = 0, g_vbo = 0, g_program = 0;
static GLuint g_fbo = 0, g_colorTexture = 0, g_depthBuffer = 0;
static CGLContextObj g_cglCtx = nullptr;
static IOSurfaceRef g_surface = nullptr;

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

static void signalHandler(int) {
    g_running = false;
}

// ---------------------------------------------------------------------------
// Shader compilation helper
// ---------------------------------------------------------------------------

static GLuint compileShader(GLenum type, const char* source) {
    GLuint shader = glCreateShader(type);
    glShaderSource(shader, 1, &source, nullptr);
    glCompileShader(shader);

    GLint success;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &success);
    if (!success) {
        char log[512];
        glGetShaderInfoLog(shader, sizeof(log), nullptr, log);
        fprintf(stderr, "Shader compile error: %s\n", log);
        return 0;
    }
    return shader;
}

static GLuint createProgram(const char* vs, const char* fs) {
    GLuint vsObj = compileShader(GL_VERTEX_SHADER, vs);
    GLuint fsObj = compileShader(GL_FRAGMENT_SHADER, fs);
    if (!vsObj || !fsObj) return 0;

    GLuint prog = glCreateProgram();
    glAttachShader(prog, vsObj);
    glAttachShader(prog, fsObj);
    glLinkProgram(prog);

    GLint success;
    glGetProgramiv(prog, GL_LINK_STATUS, &success);
    if (!success) {
        char log[512];
        glGetProgramInfoLog(prog, sizeof(log), nullptr, log);
        fprintf(stderr, "Program link error: %s\n", log);
        return 0;
    }

    glDeleteShader(vsObj);
    glDeleteShader(fsObj);
    return prog;
}

// ---------------------------------------------------------------------------
// Setup cube VAO/VBO
// ---------------------------------------------------------------------------

static void setupCube() {
    glGenVertexArrays(1, &g_vao);
    glBindVertexArray(g_vao);

    glGenBuffers(1, &g_vbo);
    glBindBuffer(GL_ARRAY_BUFFER, g_vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(cubeVertices), cubeVertices, GL_STATIC_DRAW);

    // position: location=0, 3 floats
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex), (void*)0);
    glEnableVertexAttribArray(0);

    // color: location=1, 3 floats
    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, sizeof(Vertex),
                          (void*)(3 * sizeof(float)));
    glEnableVertexAttribArray(1);

    glBindVertexArray(0);
}

// ---------------------------------------------------------------------------
// Create perspective MVP matrix (simple)
// ---------------------------------------------------------------------------

static void computeMVP(float* mvp, float angle, int width, int height) {
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

    // View: camera at (0, 0, 3), looking at origin
    float view[16] = {
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, -3, 1
    };

    // Model: rotation around Y axis
    float cosA = cosf(angle), sinA = sinf(angle);
    float model[16] = {
        cosA,  0, sinA, 0,
        0,     1, 0,    0,
       -sinA,  0, cosA, 0,
        0,     0, 0,    1
    };

    // Column-major matrix multiply: out = a * b
    // All matrices stored column-major: element(row, col) is at index[col*4+row]
    auto mul = [](const float* a, const float* b, float* out) {
        for (int i = 0; i < 16; i++) out[i] = 0;
        for (int col = 0; col < 4; col++)
            for (int row = 0; row < 4; row++)
                for (int k = 0; k < 4; k++)
                    out[col * 4 + row] += a[k * 4 + row] * b[col * 4 + k];
    };

    float viewModel[16];
    mul(view, model, viewModel);
    mul(proj, viewModel, mvp);
}

// ---------------------------------------------------------------------------
// Cleanup
// ---------------------------------------------------------------------------

static void cleanup() {
    if (g_fbo)          glDeleteFramebuffers(1, &g_fbo);
    if (g_colorTexture) glDeleteTextures(1, &g_colorTexture);
    if (g_depthBuffer)  glDeleteRenderbuffers(1, &g_depthBuffer);
    if (g_vao)          glDeleteVertexArrays(1, &g_vao);
    if (g_vbo)          glDeleteBuffers(1, &g_vbo);
    if (g_program)      glDeleteProgram(g_program);

    if (g_surface) {
        CFRelease(g_surface);
        g_surface = nullptr;
    }

    if (g_cglCtx) {
        CGLSetCurrentContext(nullptr);
        CGLDestroyContext(g_cglCtx);
        g_cglCtx = nullptr;
    }
}

// ---------------------------------------------------------------------------
// Debugger detection (macOS)
// ---------------------------------------------------------------------------

static bool amIBeingDebugged() {
    struct kinfo_proc info;
    size_t size = sizeof(info);
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    if (sysctl(mib, 4, &info, &size, NULL, 0) != 0) return false;
    return (info.kp_proc.p_flag & P_TRACED) != 0;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

int main(int argc, char* argv[]) {
    // Parse args: <surfaceID> [width] [height] [--debug]
    bool debugMode = false;
    const char* surfaceArg = nullptr;
    const char* widthArg = nullptr;
    const char* heightArg = nullptr;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--debug") == 0 || strcmp(argv[i], "-d") == 0) {
            debugMode = true;
        } else if (!surfaceArg) {
            surfaceArg = argv[i];
        } else if (!widthArg) {
            widthArg = argv[i];
        } else if (!heightArg) {
            heightArg = argv[i];
        }
    }

    if (!surfaceArg) {
        fprintf(stderr, "Usage: %s <surfaceID> [width] [height] [--debug]\n", argv[0]);
        return 1;
    }

    uint32_t surfaceID = (uint32_t)atoi(surfaceArg);
    int width  = widthArg  ? atoi(widthArg)  : 800;
    int height = heightArg ? atoi(heightArg) : 600;

    // ── 0. Debug: wait for lldb attach ──────────────────────────────
    if (debugMode) {
        printf("[cube_renderer] PID=%d — waiting for debugger to attach...\n", getpid());
        printf("[cube_renderer] Run: lldb -p %d  (or use VS Code attach config)\n", getpid());
        fflush(stdout);
        while (!amIBeingDebugged()) {
            usleep(200000);  // 200ms poll
        }
        printf("[cube_renderer] Debugger attached! Continuing...\n");
        fflush(stdout);
    }

    printf("[cube_renderer] Starting: surfaceID=%u, %dx%d\n", surfaceID, width, height);

    signal(SIGTERM, signalHandler);
    signal(SIGINT, signalHandler);

    // ── 1. Create headless OpenGL context ────────────────────────────
    CGLPixelFormatAttribute attrs[] = {
        kCGLPFAOpenGLProfile, (CGLPixelFormatAttribute)kCGLOGLPVersion_3_2_Core,
        kCGLPFAAccelerated,
        kCGLPFAColorSize, (CGLPixelFormatAttribute)24,
        kCGLPFAAlphaSize, (CGLPixelFormatAttribute)8,
        kCGLPFADepthSize, (CGLPixelFormatAttribute)24,
        (CGLPixelFormatAttribute)0
    };

    CGLPixelFormatObj pix = nullptr;
    GLint npix = 0;
    CGLError err = CGLChoosePixelFormat(attrs, &pix, &npix);
    if (err != kCGLNoError || !pix) {
        fprintf(stderr, "[cube_renderer] CGLChoosePixelFormat failed: %d\n", err);
        return 1;
    }

    err = CGLCreateContext(pix, nullptr, &g_cglCtx);  // nullptr = offscreen
    CGLReleasePixelFormat(pix);
    if (err != kCGLNoError) {
        fprintf(stderr, "[cube_renderer] CGLCreateContext failed: %d\n", err);
        return 1;
    }

    err = CGLSetCurrentContext(g_cglCtx);
    if (err != kCGLNoError) {
        fprintf(stderr, "[cube_renderer] CGLSetCurrentContext failed: %d\n", err);
        return 1;
    }

    printf("[cube_renderer] OpenGL: %s\n", glGetString(GL_VERSION));
    printf("[cube_renderer] Renderer: %s\n", glGetString(GL_RENDERER));

    // ── 2. Lookup IOSurface and bind to GL texture ─────────────────
    g_surface = IOSurfaceLookup(surfaceID);
    if (!g_surface) {
        fprintf(stderr, "[cube_renderer] IOSurfaceLookup(%u) failed\n", surfaceID);
        return 1;
    }

    GLsizei surfW = (GLsizei)IOSurfaceGetWidth(g_surface);
    GLsizei surfH = (GLsizei)IOSurfaceGetHeight(g_surface);
    printf("[cube_renderer] IOSurface size: %dx%d\n", surfW, surfH);

    // Create GL texture backed by IOSurface (ZERO COPY)
    glGenTextures(1, &g_colorTexture);
    glBindTexture(GL_TEXTURE_RECTANGLE, g_colorTexture);

    err = CGLTexImageIOSurface2D(
        g_cglCtx,
        GL_TEXTURE_RECTANGLE,
        GL_RGBA8,
        surfW, surfH,
        GL_BGRA,
        GL_UNSIGNED_INT_8_8_8_8_REV,
        g_surface,
        0  // level 0
    );

    if (err != kCGLNoError) {
        fprintf(stderr, "[cube_renderer] CGLTexImageIOSurface2D failed: %d\n", err);
        return 1;
    }
    printf("[cube_renderer] IOSurface bound to GL texture (zero-copy)\n");

    // Set texture parameters
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_RECTANGLE, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

    // ── 3. Create FBO with IOSurface texture as color attachment ───
    glGenFramebuffers(1, &g_fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_RECTANGLE, g_colorTexture, 0);

    // Depth renderbuffer (IOSurface doesn't include depth)
    glGenRenderbuffers(1, &g_depthBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, g_depthBuffer);
    glRenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT24, surfW, surfH);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT,
                              GL_RENDERBUFFER, g_depthBuffer);

    GLenum fboStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (fboStatus != GL_FRAMEBUFFER_COMPLETE) {
        fprintf(stderr, "[cube_renderer] FBO incomplete: 0x%x\n", fboStatus);
        return 1;
    }
    printf("[cube_renderer] FBO complete\n");

    // ── 4. Setup cube geometry and shader ──────────────────────────
    setupCube();
    g_program = createProgram(vertexShaderSource, fragmentShaderSource);
    if (!g_program) {
        fprintf(stderr, "[cube_renderer] Failed to create shader program\n");
        return 1;
    }
    printf("[cube_renderer] Shader program ready\n");

    GLint uMVPLoc = glGetUniformLocation(g_program, "uMVP");
    printf("[cube_renderer] uMVP location: %d\n", uMVPLoc);

    // Check first frame: render WITHOUT depth test and with identity-like MVP
    {
        printf("[cube_renderer] --- DEBUG: Rendering test quad (frame 0) ---\n");

        // Simple test: a triangle covering most of the screen (NDC coords, no matrix needed)
        float testVertices[] = {
            // positions          // colors (bright)
            -0.9f, -0.9f, 0.0f,   1.0f, 0.0f, 0.0f,  // red bottom-left
             0.9f, -0.9f, 0.0f,   0.0f, 1.0f, 0.0f,  // green bottom-right
             0.0f,  0.9f, 0.0f,   0.0f, 0.0f, 1.0f,  // blue top-center
        };

        GLuint testVAO, testVBO;
        glGenVertexArrays(1, &testVAO);
        glBindVertexArray(testVAO);
        glGenBuffers(1, &testVBO);
        glBindBuffer(GL_ARRAY_BUFFER, testVBO);
        glBufferData(GL_ARRAY_BUFFER, sizeof(testVertices), testVertices, GL_STATIC_DRAW);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(3 * sizeof(float)));
        glEnableVertexAttribArray(1);

        // Identity MVP (no transform) - vertices in NDC space
        float identityMVP[16] = {
            1,0,0,0,
            0,1,0,0,
            0,0,1,0,
            0,0,0,1
        };

        glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
        glViewport(0, 0, surfW, surfH);
        glClearColor(0.2f, 0.7f, 0.2f, 1.0f);  // bright green clear
        glClear(GL_COLOR_BUFFER_BIT);
        glDisable(GL_DEPTH_TEST);

        glUseProgram(g_program);
        glUniformMatrix4fv(uMVPLoc, 1, GL_FALSE, identityMVP);
        glBindVertexArray(testVAO);
        glDrawArrays(GL_TRIANGLES, 0, 3);  // single triangle
        glBindVertexArray(0);
        glUseProgram(0);
        glFlush();

        printf("[cube_renderer] Test quad rendered with glDrawArrays\n");

        // Check for errors
        GLenum glErr = glGetError();
        if (glErr != GL_NO_ERROR) {
            fprintf(stderr, "[cube_renderer] GL Error after test quad: 0x%x\n", glErr);
        } else {
            printf("[cube_renderer] No GL errors after test quad\n");
        }

        // Cleanup test objects
        glDeleteVertexArrays(1, &testVAO);
        glDeleteBuffers(1, &testVBO);

        // Let test frame be visible for 1 second
        sleep(1);
    }

    // ── 5. Render loop ─────────────────────────────────────────────
    printf("[cube_renderer] Entering cube render loop...\n");

    float angle = 0.0f;
    const float anglePerFrame = 0.02f;
    int frameCount = 0;

    while (g_running) {
        glBindFramebuffer(GL_FRAMEBUFFER, g_fbo);
        glViewport(0, 0, surfW, surfH);

        // Alternate between red and blue clear every 30 frames for visibility
        if ((frameCount / 30) % 2 == 0) {
            glClearColor(0.3f, 0.15f, 0.15f, 1.0f);  // dark red
        } else {
            glClearColor(0.15f, 0.15f, 0.35f, 1.0f);  // dark blue
        }
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
        glEnable(GL_DEPTH_TEST);

        float mvp[16];
        computeMVP(mvp, angle, surfW, surfH);

        // Debug: print MVP and a sample vertex transform every 60 frames
        if (frameCount % 60 == 0) {
            printf("[cube_renderer] Frame %d, angle=%.2f\n", frameCount, angle);
            printf("  MVP row0: [%.3f, %.3f, %.3f, %.3f]\n", mvp[0], mvp[4], mvp[8], mvp[12]);
            printf("  MVP row1: [%.3f, %.3f, %.3f, %.3f]\n", mvp[1], mvp[5], mvp[9], mvp[13]);
            printf("  MVP row2: [%.3f, %.3f, %.3f, %.3f]\n", mvp[2], mvp[6], mvp[10], mvp[14]);
            printf("  MVP row3: [%.3f, %.3f, %.3f, %.3f]\n", mvp[3], mvp[7], mvp[11], mvp[15]);

            // Manually transform vertex (0.5, 0.5, 0.5) — front top right corner
            float vx = 0.5f, vy = 0.5f, vz = 0.5f;
            float cx = mvp[0]*vx + mvp[4]*vy + mvp[8]*vz + mvp[12];
            float cy = mvp[1]*vx + mvp[5]*vy + mvp[9]*vz + mvp[13];
            float cz = mvp[2]*vx + mvp[6]*vy + mvp[10]*vz + mvp[14];
            float cw = mvp[3]*vx + mvp[7]*vy + mvp[11]*vz + mvp[15];
            printf("  Projected (0.5,0.5,0.5): clip=(%.2f,%.2f,%.2f,%.2f) ndc=(%.2f,%.2f)\n",
                   cx, cy, cz, cw, cx/cw, cy/cw);
        }

        glUseProgram(g_program);
        glUniformMatrix4fv(uMVPLoc, 1, GL_FALSE, mvp);

        glBindVertexArray(g_vao);
        glDrawArrays(GL_TRIANGLES, 0, 36);
        glBindVertexArray(0);
        glUseProgram(0);

        // Check GL errors every 60 frames
        if (frameCount % 60 == 0) {
            GLenum glErr = glGetError();
            if (glErr != GL_NO_ERROR) {
                fprintf(stderr, "[cube_renderer] GL Error: 0x%x at frame %d\n", glErr, frameCount);
            }
        }

        glFlush();

        angle += anglePerFrame;
        if (angle > 2.0f * M_PI) angle -= 2.0f * M_PI;
        frameCount++;

        usleep(16667);
    }

    // ── 6. Cleanup ─────────────────────────────────────────────────
    printf("[cube_renderer] Shutting down...\n");
    cleanup();
    printf("[cube_renderer] Done.\n");
    return 0;
}
