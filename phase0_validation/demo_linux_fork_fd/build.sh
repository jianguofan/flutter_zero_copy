#!/bin/bash
# build.sh - Linux DMA-BUF fd 继承验证 Demo 构建脚本

set -e

echo "========================================"
echo "Building Linux DMA-BUF fork Demo"
echo "========================================"
echo

# 检查依赖
echo "Step 1: 检查依赖..."

missing_deps=()

if ! pkg-config --exists gbm; then
    missing_deps+=("libgbm-dev")
fi

if ! pkg-config --exists egl; then
    missing_deps+=("libegl1-mesa-dev")
fi

if ! pkg-config --exists gl; then
    missing_deps+=("libgl1-mesa-dev")
fi

if ! pkg-config --exists libdrm; then
    missing_deps+=("libdrm-dev")
fi

if [ ${#missing_deps[@]} -ne 0 ]; then
    echo "  ❌ 缺少依赖:"
    for dep in "${missing_deps[@]}"; do
        echo "     - $dep"
    done
    echo
    echo "  安装命令 (Ubuntu/Debian):"
    echo "    sudo apt install ${missing_deps[*]}"
    echo
    echo "  安装命令 (Fedora):"
    echo "    sudo dnf install mesa-libgbm-devel mesa-libEGL-devel mesa-libGL-devel libdrm-devel"
    exit 1
fi

echo "  ✅ 所有依赖已安装"
echo

# 构建
echo "Step 2: 编译..."

gcc -Wall -Wextra -O2 \
    demo_linux_fork_fd.c \
    -o demo_linux_fork_fd \
    $(pkg-config --cflags --libs gbm egl gl libdrm) \
    -lm

if [ $? -eq 0 ]; then
    echo "  ✅ 编译成功"
else
    echo "  ❌ 编译失败"
    exit 1
fi

echo
echo "========================================"
echo "Build SUCCESS"
echo "========================================"
echo "Output: ./demo_linux_fork_fd"
echo
echo "Run: ./demo_linux_fork_fd"
echo

# 检查 DRM 设备
echo "检查 DRM 设备:"
if [ -e /dev/dri/renderD128 ]; then
    echo "  ✅ /dev/dri/renderD128 存在"
elif [ -e /dev/dri/card0 ]; then
    echo "  ✅ /dev/dri/card0 存在"
else
    echo "  ⚠️  未找到 DRM 设备"
    echo "     需要 GPU 和 DRM 驱动支持"
fi
echo
