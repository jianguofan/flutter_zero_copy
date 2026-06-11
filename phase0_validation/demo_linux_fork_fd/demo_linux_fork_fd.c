// demo_linux_fork_fd.c - Linux DMA-BUF fd 继承验证
//
// 功能：
// 1. 父进程创建 GBM buffer object 并获取 DMA-BUF fd
// 2. fork() 子进程
// 3. 子进程使用继承的 fd 创建 EGLImage 并绑定到 GL texture
// 4. 子进程渲染绿色到纹理
// 5. 父进程验证 gbm_bo 内容为绿色
//
// 编译: gcc demo_linux_fork_fd.c -o demo_linux_fork_fd -lgbm -lEGL -lGL -ldrm
//
// 依赖:
//   - libgbm-dev
//   - libegl1-mesa-dev
//   - libgl1-mesa-dev
//   - libdrm-dev

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <errno.h>

#include <gbm.h>
#include <EGL/egl.h>
#include <EGL/eglext.h>
#include <GL/gl.h>

#define WIDTH 800
#define HEIGHT 600

// EGL DMA-BUF extension function pointers
static PFNEGLCREATEIMAGEKHRPROC eglCreateImageKHR = NULL;
static PFNEGLDESTROYIMAGEKHRPROC eglDestroyImageKHR = NULL;
static PFNGLEGLIMAGETARGETTEXTURE2DOESPROC glEGLImageTargetTexture2DOES = NULL;

// 初始化 EGL DMA-BUF 扩展
int init_egl_extensions(EGLDisplay display) {
    const char* egl_exts = eglQueryString(display, EGL_EXTENSIONS);
    if (!egl_exts) {
        fprintf(stderr, "[ERROR] eglQueryString(EGL_EXTENSIONS) 失败\n");
        return 0;
    }

    // 检查 EGL_EXT_image_dma_buf_import
    if (!strstr(egl_exts, "EGL_EXT_image_dma_buf_import")) {
        fprintf(stderr, "[ERROR] EGL_EXT_image_dma_buf_import 不支持\n");
        fprintf(stderr, "        当前驱动不支持 DMA-BUF，需要 Mesa 或较新的 NVIDIA 驱动\n");
        return 0;
    }

    // 加载函数指针
    eglCreateImageKHR = (PFNEGLCREATEIMAGEKHRPROC)
        eglGetProcAddress("eglCreateImageKHR");
    eglDestroyImageKHR = (PFNEGLDESTROYIMAGEKHRPROC)
        eglGetProcAddress("eglDestroyImageKHR");
    glEGLImageTargetTexture2DOES = (PFNGLEGLIMAGETARGETTEXTURE2DOESPROC)
        eglGetProcAddress("glEGLImageTargetTexture2DOES");

    if (!eglCreateImageKHR || !eglDestroyImageKHR || !glEGLImageTargetTexture2DOES) {
        fprintf(stderr, "[ERROR] 加载 EGL DMA-BUF 函数指针失败\n");
        return 0;
    }

    return 1;
}

// 子进程：使用继承的 fd 创建 EGLImage 并渲染
int child_process(int dmaBufFd, int width, int height, int stride) {
    printf("\n[CHILD] ========================================\n");
    printf("[CHILD] 子进程启动 (PID: %d)\n", pid, getpid());
    printf("[CHILD] ========================================\n\n");

    printf("[CHILD] Step 1: 验证继承的 fd...\n");
    printf("[CHILD]   dmaBufFd = %d (从父进程继承)\n", dmaBufFd);

    // 验证 fd 有效
    if (fcntl(dmaBufFd, F_GETFD) == -1) {
        fprintf(stderr, "[CHILD] ERROR: fd %d 无效 (errno=%d: %s)\n",
                dmaBufFd, errno, strerror(errno));
        return 1;
    }
    printf("[CHILD]   ✅ fd 有效\n");

    // ── 2. 初始化 EGL ──────────────────────────────────────
    printf("[CHILD] Step 2: 初始化 EGL...\n");

    EGLDisplay display = eglGetDisplay(EGL_DEFAULT_DISPLAY);
    if (display == EGL_NO_DISPLAY) {
        fprintf(stderr, "[CHILD] ERROR: eglGetDisplay 失败\n");
        return 1;
    }

    EGLint major, minor;
    if (!eglInitialize(display, &major, &minor)) {
        fprintf(stderr, "[CHILD] ERROR: eglInitialize 失败\n");
        return 1;
    }
    printf("[CHILD]   ✅ EGL %d.%d 初始化成功\n", major, minor);

    // 加载 DMA-BUF 扩展
    if (!init_egl_extensions(display)) {
        return 1;
    }
    printf("[CHILD]   ✅ EGL DMA-BUF 扩展加载成功\n");

    // ── 3. 创建 EGL context ────────────────────────────────
    printf("[CHILD] Step 3: 创建 EGL context...\n");

    eglBindAPI(EGL_OPENGL_API);

    EGLint config_attribs[] = {
        EGL_SURFACE_TYPE, EGL_PBUFFER_BIT,
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        EGL_ALPHA_SIZE, 8,
        EGL_NONE
    };

    EGLConfig config;
    EGLint num_configs;
    if (!eglChooseConfig(display, config_attribs, &config, 1, &num_configs)) {
        fprintf(stderr, "[CHILD] ERROR: eglChooseConfig 失败\n");
        return 1;
    }

    EGLint pbuffer_attribs[] = {
        EGL_WIDTH, 1,
        EGL_HEIGHT, 1,
        EGL_NONE
    };
    EGLSurface surface = eglCreatePbufferSurface(display, config, pbuffer_attribs);
    if (surface == EGL_NO_SURFACE) {
        fprintf(stderr, "[CHILD] ERROR: eglCreatePbufferSurface 失败\n");
        return 1;
    }

    EGLContext context = eglCreateContext(display, config, EGL_NO_CONTEXT, NULL);
    if (context == EGL_NO_CONTEXT) {
        fprintf(stderr, "[CHILD] ERROR: eglCreateContext 失败\n");
        return 1;
    }

    if (!eglMakeCurrent(display, surface, surface, context)) {
        fprintf(stderr, "[CHILD] ERROR: eglMakeCurrent 失败\n");
        return 1;
    }
    printf("[CHILD]   ✅ EGL context 创建成功\n");

    // ── 4. 从 DMA-BUF fd 创建 EGLImage (关键!) ─────────────
    printf("[CHILD] Step 4: 从 DMA-BUF fd 创建 EGLImage...\n");

    EGLint img_attribs[] = {
        EGL_WIDTH, width,
        EGL_HEIGHT, height,
        EGL_LINUX_DRM_FOURCC_EXT, 0x34325241,  // GBM_FORMAT_ARGB8888 = 'AR24'
        EGL_DMA_BUF_PLANE0_FD_EXT, dmaBufFd,
        EGL_DMA_BUF_PLANE0_OFFSET_EXT, 0,
        EGL_DMA_BUF_PLANE0_PITCH_EXT, stride,
        EGL_NONE
    };

    EGLImage eglImage = eglCreateImageKHR(
        display,
        EGL_NO_CONTEXT,
        EGL_LINUX_DMA_BUF_EXT,
        NULL,
        img_attribs
    );

    if (eglImage == EGL_NO_IMAGE_KHR) {
        fprintf(stderr, "[CHILD] ERROR: eglCreateImageKHR 失败\n");
        fprintf(stderr, "[CHILD]        可能原因:\n");
        fprintf(stderr, "[CHILD]          • DMA-BUF fd 无效\n");
        fprintf(stderr, "[CHILD]          • 格式不支持\n");
        fprintf(stderr, "[CHILD]          • 驱动不支持 DMA-BUF import\n");
        return 1;
    }
    printf("[CHILD]   ✅ EGLImage 创建成功\n");

    // ── 5. 绑定 EGLImage 到 GL texture ─────────────────────
    printf("[CHILD] Step 5: 绑定 EGLImage 到 GL texture...\n");

    GLuint texId;
    glGenTextures(1, &texId);
    glBindTexture(GL_TEXTURE_2D, texId);
    glEGLImageTargetTexture2DOES(GL_TEXTURE_2D, eglImage);

    GLenum glErr = glGetError();
    if (glErr != GL_NO_ERROR) {
        fprintf(stderr, "[CHILD] ERROR: glEGLImageTargetTexture2DOES 失败 (GL error: 0x%x)\n", glErr);
        return 1;
    }
    printf("[CHILD]   ✅ GL texture 绑定成功 (texture ID: %u)\n", texId);

    // ── 6. 创建 FBO 并渲染绿色 ──────────────────────────────
    printf("[CHILD] Step 6: 渲染绿色到纹理...\n");

    GLuint fbo;
    glGenFramebuffers(1, &fbo);
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, texId, 0);

    GLenum fboStatus = glCheckFramebufferStatus(GL_FRAMEBUFFER);
    if (fboStatus != GL_FRAMEBUFFER_COMPLETE) {
        fprintf(stderr, "[CHILD] ERROR: FBO 不完整 (status: 0x%x)\n", fboStatus);
        return 1;
    }

    glViewport(0, 0, width, height);
    glClearColor(0.0f, 1.0f, 0.0f, 1.0f);  // 绿色
    glClear(GL_COLOR_BUFFER_BIT);
    glFlush();

    printf("[CHILD]   ✅ 纹理已清除为绿色 (RGBA: 0.0, 1.0, 0.0, 1.0)\n");

    // ── 7. 清理 ────────────────────────────────────────────
    glDeleteFramebuffers(1, &fbo);
    glDeleteTextures(1, &texId);
    eglDestroyImageKHR(display, eglImage);
    eglDestroyContext(display, context);
    eglDestroySurface(display, surface);
    eglTerminate(display);

    printf("\n[CHILD] ========================================\n");
    printf("[CHILD] ✅ 子进程完成\n");
    printf("[CHILD] ========================================\n");

    return 0;
}

int main(int argc, char* argv[]) {
    printf("========================================\n");
    printf("Linux DMA-BUF fd 继承验证\n");
    printf("========================================\n\n");

    // ── 1. 打开 DRM 设备 ───────────────────────────────────
    printf("[PARENT] Step 1: 打开 DRM 设备...\n");

    int drm_fd = open("/dev/dri/renderD128", O_RDWR);
    if (drm_fd < 0) {
        fprintf(stderr, "[PARENT] ERROR: 打开 /dev/dri/renderD128 失败\n");
        fprintf(stderr, "[PARENT]        尝试其他设备...\n");
        drm_fd = open("/dev/dri/card0", O_RDWR);
        if (drm_fd < 0) {
            fprintf(stderr, "[PARENT] ERROR: 无法打开 DRM 设备\n");
            return 1;
        }
    }
    printf("[PARENT]   ✅ DRM 设备打开成功 (fd: %d)\n", drm_fd);

    // ── 2. 创建 GBM 设备 ───────────────────────────────────
    printf("[PARENT] Step 2: 创建 GBM 设备...\n");

    struct gbm_device* gbm_dev = gbm_create_device(drm_fd);
    if (!gbm_dev) {
        fprintf(stderr, "[PARENT] ERROR: gbm_create_device 失败\n");
        close(drm_fd);
        return 1;
    }
    printf("[PARENT]   ✅ GBM 设备创建成功\n");

    // ── 3. 创建 GBM buffer object ──────────────────────────
    printf("[PARENT] Step 3: 创建 GBM buffer object (%dx%d ARGB8888)...\n",
           WIDTH, HEIGHT);

    struct gbm_bo* bo = gbm_bo_create(
        gbm_dev,
        WIDTH, HEIGHT,
        GBM_FORMAT_ARGB8888,  // 修正：与 macOS/Windows BGRA 对应
        GBM_BO_USE_RENDERING | GBM_BO_USE_LINEAR
    );

    if (!bo) {
        fprintf(stderr, "[PARENT] ERROR: gbm_bo_create 失败\n");
        gbm_device_destroy(gbm_dev);
        close(drm_fd);
        return 1;
    }

    int stride = gbm_bo_get_stride(bo);
    printf("[PARENT]   ✅ GBM BO 创建成功 (stride: %d bytes)\n", stride);

    // ── 4. 获取 DMA-BUF fd ─────────────────────────────────
    printf("[PARENT] Step 4: 获取 DMA-BUF fd...\n");

    int dmaBufFd = gbm_bo_get_fd(bo);
    if (dmaBufFd < 0) {
        fprintf(stderr, "[PARENT] ERROR: gbm_bo_get_fd 失败\n");
        gbm_bo_destroy(bo);
        gbm_device_destroy(gbm_dev);
        close(drm_fd);
        return 1;
    }
    printf("[PARENT]   ✅ DMA-BUF fd: %d\n", dmaBufFd);

    // ── 5. fork 子进程 (关键!) ─────────────────────────────
    printf("[PARENT] Step 5: fork 子进程...\n");
    printf("[PARENT]   子进程将继承 fd %d\n\n", dmaBufFd);

    pid_t pid = fork();

    if (pid < 0) {
        fprintf(stderr, "[PARENT] ERROR: fork 失败\n");
        close(dmaBufFd);
        gbm_bo_destroy(bo);
        gbm_device_destroy(gbm_dev);
        close(drm_fd);
        return 1;
    }

    if (pid == 0) {
        // 子进程
        int exitCode = child_process(dmaBufFd, WIDTH, HEIGHT, stride);
        exit(exitCode);
    }

    // 父进程继续
    printf("[PARENT]   ✅ 子进程已启动 (PID: %d)\n", pid);
    printf("[PARENT]   等待子进程完成...\n");

    // ── 6. 等待子进程 ──────────────────────────────────────
    int status;
    waitpid(pid, &status, 0);

    int exitCode = WIFEXITED(status) ? WEXITSTATUS(status) : -1;
    printf("\n[PARENT] Step 6: 子进程已退出 (退出码: %d)\n", exitCode);

    if (exitCode != 0) {
        fprintf(stderr, "[PARENT] ERROR: 子进程返回错误码\n");
        close(dmaBufFd);
        gbm_bo_destroy(bo);
        gbm_device_destroy(gbm_dev);
        close(drm_fd);
        return 1;
    }

    // ── 7. 验证 gbm_bo 内容为绿色 ───────────────────────────
    printf("[PARENT] Step 7: 验证 gbm_bo 内容 (应为绿色)...\n");

    // Map buffer object 到 CPU 内存
    void* map_data;
    uint32_t map_stride;
    map_data = gbm_bo_map(bo, 0, 0, WIDTH, HEIGHT,
                          GBM_BO_TRANSFER_READ, &map_stride, &map_data);

    if (!map_data) {
        fprintf(stderr, "[PARENT] WARNING: gbm_bo_map 失败，跳过验证\n");
        fprintf(stderr, "[PARENT]          (某些驱动不支持 CPU mapping)\n");
    } else {
        // 读取中心像素
        uint32_t* pixels = (uint32_t*)map_data;
        uint32_t centerPixel = pixels[300 * (map_stride / 4) + 400];

        gbm_bo_unmap(bo, map_data);

        // 解析颜色 (ARGB8888 = 0xAARRGGBB in memory)
        uint8_t a = (centerPixel >> 24) & 0xFF;
        uint8_t r = (centerPixel >> 16) & 0xFF;
        uint8_t g = (centerPixel >> 8) & 0xFF;
        uint8_t b = (centerPixel >> 0) & 0xFF;

        printf("[PARENT]   中心像素 (400, 300) 颜色:\n");
        printf("[PARENT]     R=%d, G=%d, B=%d, A=%d\n", r, g, b, a);
        printf("[PARENT]     原始值: 0x%08X\n", centerPixel);

        bool isGreen = (g > 250 && r < 5 && b < 5);

        if (isGreen) {
            printf("\n========================================\n");
            printf("✅✅✅ 验证成功！ ✅✅✅\n");
            printf("========================================\n");
            printf("Linux fork + DMA-BUF fd 继承工作正常:\n");
            printf("  • 父进程创建 GBM BO 并获取 fd\n");
            printf("  • fork() 子进程\n");
            printf("  • 子进程继承 fd 并创建 EGLImage\n");
            printf("  • 子进程渲染到纹理\n");
            printf("  • 父进程看到修改后的内容\n");
            printf("\n");
            printf("✅ 可以进入 Phase 3: Linux 实施 (零拷贝路径)\n");
            printf("========================================\n");
        } else {
            printf("\n========================================\n");
            printf("⚠️⚠️⚠️ 验证警告 ⚠️⚠️⚠️\n");
            printf("========================================\n");
            printf("颜色不是绿色 (期望 G>250, R<5, B<5)\n");
            printf("可能原因:\n");
            printf("  • 子进程渲染未生效\n");
            printf("  • 驱动缓存问题\n");
            printf("  • 格式不匹配\n");
            printf("\n");
            printf("建议: 使用 CPU fallback 路径作为 Linux 实现\n");
            printf("========================================\n");
        }
    }

    // ── 8. 清理 ────────────────────────────────────────────
    close(dmaBufFd);
    gbm_bo_destroy(bo);
    gbm_device_destroy(gbm_dev);
    close(drm_fd);

    return 0;
}
