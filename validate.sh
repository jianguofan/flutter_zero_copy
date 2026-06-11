#!/bin/bash
# validate.sh - Phase 0 验证执行工具
# 用法: ./validate.sh [windows|linux|all]

set -e

COLOR_RESET='\033[0m'
COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'

echo -e "${COLOR_BLUE}========================================"
echo "Phase 0 验证执行工具"
echo -e "========================================${COLOR_RESET}"
echo

# 检测操作系统
detect_os() {
    case "$(uname -s)" in
        Darwin*)    echo "macos";;
        Linux*)     echo "linux";;
        MINGW*|MSYS*|CYGWIN*) echo "windows";;
        *)          echo "unknown";;
    esac
}

OS=$(detect_os)
echo -e "${COLOR_BLUE}检测到操作系统: ${COLOR_YELLOW}${OS}${COLOR_RESET}"
echo

# 显示帮助
show_help() {
    echo "用法: ./validate.sh [选项]"
    echo
    echo "选项:"
    echo "  windows    - 运行 Windows 验证 (需要 Windows 环境)"
    echo "  linux      - 运行 Linux 验证 (需要 Linux 环境)"
    echo "  all        - 运行所有验证 (需要对应环境)"
    echo "  help       - 显示此帮助"
    echo
    echo "示例:"
    echo "  ./validate.sh linux      # 只运行 Linux 验证"
    echo "  ./validate.sh            # 根据当前系统自动选择"
    echo
}

# Linux 验证
run_linux_validation() {
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}运行 Linux DMA-BUF 验证${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo

    cd phase0_validation/demo_linux_fork_fd

    # 检查依赖
    echo "检查依赖..."
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
        echo -e "${COLOR_RED}❌ 缺少依赖:${COLOR_RESET}"
        for dep in "${missing_deps[@]}"; do
            echo "   - $dep"
        done
        echo
        echo -e "${COLOR_YELLOW}安装命令 (Ubuntu/Debian):${COLOR_RESET}"
        echo "  sudo apt install ${missing_deps[*]}"
        echo
        echo -e "${COLOR_YELLOW}安装命令 (Fedora):${COLOR_RESET}"
        echo "  sudo dnf install mesa-libgbm-devel mesa-libEGL-devel mesa-libGL-devel libdrm-devel"
        echo
        exit 1
    fi

    echo -e "${COLOR_GREEN}✅ 所有依赖已安装${COLOR_RESET}"
    echo

    # 构建
    echo "构建 demo..."
    chmod +x build.sh
    ./build.sh
    echo

    # 运行
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}运行验证...${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo

    ./demo_linux_fork_fd

    EXIT_CODE=$?
    echo

    if [ $EXIT_CODE -eq 0 ]; then
        echo -e "${COLOR_GREEN}✅✅✅ Linux 验证成功！ ✅✅✅${COLOR_RESET}"
        echo
        echo -e "${COLOR_GREEN}下一步: 进入 Phase 3 (Linux 实施)${COLOR_RESET}"
        echo "  - 如果看到 \"零拷贝路径\" → 实施 fork+fd 方案 (5-7 天)"
        echo "  - 如果看到 \"CPU fallback\" → 实施 CPU fallback (3-4 天)"
    else
        echo -e "${COLOR_RED}❌ Linux 验证失败${COLOR_RESET}"
        echo
        echo -e "${COLOR_YELLOW}建议: 使用 CPU fallback 方案${COLOR_RESET}"
    fi

    cd ../..
}

# Windows 验证
run_windows_validation() {
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}运行 Windows Named Handle 验证${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo

    echo -e "${COLOR_YELLOW}注意: Windows 验证需要在 Windows 环境中运行${COLOR_RESET}"
    echo
    echo "步骤:"
    echo "1. 打开 'Developer Command Prompt for VS 2022'"
    echo "2. cd phase0_validation\\demo_windows_named_handle"
    echo "3. build.bat"
    echo "4. cd build"
    echo "5. parent.exe"
    echo
    echo "或者在 Git Bash 中:"
    echo "  cd phase0_validation/demo_windows_named_handle"
    echo "  cmd //c build.bat"
    echo "  cd build"
    echo "  ./parent.exe"
    echo
}

# macOS 提示
show_macos_note() {
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo -e "${COLOR_GREEN}macOS 平台${COLOR_RESET}"
    echo -e "${COLOR_BLUE}========================================${COLOR_RESET}"
    echo
    echo -e "${COLOR_GREEN}✅ macOS 实现已完成，无需验证${COLOR_RESET}"
    echo
    echo "当前 macOS 实现已经是跨进程架构，使用 IOSurface 零拷贝机制。"
    echo
    echo "如果要验证其他平台:"
    echo "  - Windows: 需要 Windows 环境"
    echo "  - Linux: 需要 Linux 环境或虚拟机"
    echo
}

# 主逻辑
main() {
    local target="${1:-auto}"

    case "$target" in
        help|--help|-h)
            show_help
            exit 0
            ;;

        windows)
            if [ "$OS" != "windows" ]; then
                echo -e "${COLOR_YELLOW}⚠️  当前不是 Windows 环境${COLOR_RESET}"
                echo
            fi
            run_windows_validation
            ;;

        linux)
            if [ "$OS" != "linux" ]; then
                echo -e "${COLOR_RED}❌ 当前不是 Linux 环境${COLOR_RESET}"
                echo
                echo "Linux 验证需要在 Linux 系统上运行"
                echo "请使用 Linux 机器或虚拟机"
                exit 1
            fi
            run_linux_validation
            ;;

        all)
            if [ "$OS" == "linux" ]; then
                run_linux_validation
            elif [ "$OS" == "windows" ]; then
                run_windows_validation
            else
                echo -e "${COLOR_YELLOW}当前系统无法运行验证${COLOR_RESET}"
                echo
                show_help
            fi
            ;;

        auto)
            case "$OS" in
                macos)
                    show_macos_note
                    ;;
                linux)
                    run_linux_validation
                    ;;
                windows)
                    run_windows_validation
                    ;;
                *)
                    echo -e "${COLOR_RED}❌ 未知操作系统${COLOR_RESET}"
                    show_help
                    exit 1
                    ;;
            esac
            ;;

        *)
            echo -e "${COLOR_RED}❌ 未知选项: $target${COLOR_RESET}"
            echo
            show_help
            exit 1
            ;;
    esac
}

# 运行
main "$@"
