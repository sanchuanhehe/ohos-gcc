#!/bin/bash
# Quick build examples for GCC OHOS toolchain

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "============================================"
echo "GCC for OpenHarmony - Quick Build Examples"
echo "============================================"
echo ""

# Example 1: AArch64 (most common for OHOS)
example_aarch64() {
    echo "Example 1: Building GCC for AArch64 OHOS"
    echo "-----------------------------------------"
    echo "Target: aarch64-linux-ohos"
    echo "Prefix: ${HOME}/ohos-toolchain/aarch64"
    echo ""
    read -p "Build this configuration? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        "${SCRIPT_DIR}/build.sh" \
            --target=aarch64-linux-ohos \
            --prefix="${HOME}/ohos-toolchain/aarch64" \
            --enable-languages=c,c++
    fi
}

# Example 2: ARM 32-bit hard float
example_arm() {
    echo "Example 2: Building GCC for ARM OHOS (hard float)"
    echo "-------------------------------------------------"
    echo "Target: armhf-linux-ohos"
    echo "Prefix: ${HOME}/ohos-toolchain/arm"
    echo ""
    read -p "Build this configuration? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        "${SCRIPT_DIR}/build.sh" \
            --target=armhf-linux-ohos \
            --prefix="${HOME}/ohos-toolchain/arm" \
            --enable-languages=c,c++
    fi
}

# Example 3: x86_64
example_x86_64() {
    echo "Example 3: Building GCC for x86_64 OHOS"
    echo "---------------------------------------"
    echo "Target: x86_64-linux-ohos"
    echo "Prefix: ${HOME}/ohos-toolchain/x86_64"
    echo ""
    read -p "Build this configuration? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        "${SCRIPT_DIR}/build.sh" \
            --target=x86_64-linux-ohos \
            --prefix="${HOME}/ohos-toolchain/x86_64" \
            --enable-languages=c,c++
    fi
}

# Example 4: RISC-V 64
example_riscv64() {
    echo "Example 4: Building GCC for RISC-V 64 OHOS"
    echo "------------------------------------------"
    echo "Target: riscv64-linux-ohos"
    echo "Prefix: ${HOME}/ohos-toolchain/riscv64"
    echo ""
    read -p "Build this configuration? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        "${SCRIPT_DIR}/build.sh" \
            --target=riscv64-linux-ohos \
            --prefix="${HOME}/ohos-toolchain/riscv64" \
            --enable-languages=c,c++
    fi
}

# Example 5: All architectures
example_all() {
    echo "Example 5: Building GCC for all architectures"
    echo "---------------------------------------------"
    echo "This will build toolchains for:"
    echo "  - aarch64-linux-ohos"
    echo "  - arm-linux-ohos"
    echo "  - x86_64-linux-ohos"
    echo "  - riscv64-linux-ohos"
    echo ""
    echo "Install prefix: ${HOME}/ohos-toolchain/<arch>"
    echo ""
    read -p "Build all configurations? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        for target in aarch64-linux-ohos arm-linux-ohos x86_64-linux-ohos riscv64-linux-ohos; do
            arch="${target%%-*}"
            echo ""
            echo "=====> Building ${target}..."
            "${SCRIPT_DIR}/build.sh" \
                --target="${target}" \
                --prefix="${HOME}/ohos-toolchain/${arch}" \
                --enable-languages=c,c++ || {
                echo "Failed to build ${target}"
                continue
            }
        done
        
        echo ""
        echo "All toolchains built successfully!"
        echo "Add to PATH:"
        echo "  export PATH=\${HOME}/ohos-toolchain/aarch64/bin:\$PATH"
    fi
}

# Example 6: Custom build with sysroot
example_custom() {
    echo "Example 6: Custom build with sysroot"
    echo "------------------------------------"
    echo ""
    read -p "Target triplet (e.g., aarch64-linux-ohos): " target
    read -p "Install prefix (e.g., /opt/ohos-gcc): " prefix
    read -p "Sysroot path (leave empty if none): " sysroot
    read -p "Languages (e.g., c,c++,fortran): " languages
    
    [ -z "$target" ] && target="aarch64-linux-ohos"
    [ -z "$prefix" ] && prefix="${HOME}/ohos-toolchain"
    [ -z "$languages" ] && languages="c,c++"
    
    cmd="${SCRIPT_DIR}/build.sh --target=${target} --prefix=${prefix} --enable-languages=${languages}"
    [ -n "$sysroot" ] && cmd="${cmd} --sysroot=${sysroot}"
    
    echo ""
    echo "Command to execute:"
    echo "  ${cmd}"
    echo ""
    read -p "Execute this command? (y/N): " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        eval "${cmd}"
    fi
}

# Menu
show_menu() {
    echo ""
    echo "Select a build example:"
    echo ""
    echo "  1) AArch64 (ARM 64-bit) - Recommended for OHOS devices"
    echo "  2) ARM (ARM 32-bit hard float)"
    echo "  3) x86_64 (Intel/AMD 64-bit)"
    echo "  4) RISC-V 64"
    echo "  5) All architectures"
    echo "  6) Custom build"
    echo "  q) Quit"
    echo ""
    read -p "Enter your choice [1-6,q]: " choice
    
    case "$choice" in
        1) example_aarch64 ;;
        2) example_arm ;;
        3) example_x86_64 ;;
        4) example_riscv64 ;;
        5) example_all ;;
        6) example_custom ;;
        q|Q) echo "Goodbye!"; exit 0 ;;
        *) echo "Invalid choice"; show_menu ;;
    esac
}

# Main
if [ $# -eq 0 ]; then
    show_menu
else
    case "$1" in
        aarch64) example_aarch64 ;;
        arm) example_arm ;;
        x86_64) example_x86_64 ;;
        riscv64) example_riscv64 ;;
        all) example_all ;;
        custom) example_custom ;;
        *)
            echo "Usage: $0 [aarch64|arm|x86_64|riscv64|all|custom]"
            exit 1
            ;;
    esac
fi
