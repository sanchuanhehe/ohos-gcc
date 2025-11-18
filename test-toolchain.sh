#!/bin/bash
# Test script to verify GCC OHOS toolchain installation

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}ERROR: $*${NC}" >&2
    exit 1
}

success() {
    echo -e "${GREEN}✓ $*${NC}"
}

warning() {
    echo -e "${YELLOW}⚠ $*${NC}"
}

info() {
    echo -e "→ $*"
}

# Check if toolchain path is provided
if [ $# -lt 1 ]; then
    echo "Usage: $0 <toolchain-prefix> [target]"
    echo ""
    echo "Example:"
    echo "  $0 /opt/ohos-gcc aarch64-linux-ohos"
    echo "  $0 \${HOME}/ohos-toolchain/aarch64"
    exit 1
fi

TOOLCHAIN_PREFIX="$1"
TARGET="${2:-aarch64-linux-ohos}"

echo "=========================================="
echo "GCC OHOS Toolchain Test"
echo "=========================================="
echo ""
info "Toolchain prefix: ${TOOLCHAIN_PREFIX}"
info "Target: ${TARGET}"
echo ""

# Extract architecture from target
ARCH="${TARGET%%-*}"

# Test 1: Check if toolchain directory exists
info "Checking toolchain directory..."
if [ ! -d "${TOOLCHAIN_PREFIX}" ]; then
    error "Toolchain directory not found: ${TOOLCHAIN_PREFIX}"
fi
success "Toolchain directory exists"

# Test 2: Check if bin directory exists
info "Checking bin directory..."
if [ ! -d "${TOOLCHAIN_PREFIX}/bin" ]; then
    error "Toolchain bin directory not found: ${TOOLCHAIN_PREFIX}/bin"
fi
success "Bin directory exists"

# Test 3: Check GCC compiler
info "Checking GCC compiler..."
GCC="${TOOLCHAIN_PREFIX}/bin/${TARGET}-gcc"
if [ ! -x "${GCC}" ]; then
    error "GCC compiler not found or not executable: ${GCC}"
fi
success "GCC compiler found"

# Test 4: Check GCC version
info "Checking GCC version..."
VERSION_OUTPUT=$("${GCC}" --version 2>&1 | head -1)
echo "  ${VERSION_OUTPUT}"
if ! echo "${VERSION_OUTPUT}" | grep -q "OHOS"; then
    warning "GCC version string doesn't contain 'OHOS'"
fi
success "GCC version check passed"

# Test 5: Check G++ compiler
info "Checking G++ compiler..."
GXX="${TOOLCHAIN_PREFIX}/bin/${TARGET}-g++"
if [ ! -x "${GXX}" ]; then
    warning "G++ compiler not found: ${GXX}"
else
    success "G++ compiler found"
fi

# Test 6: Check other tools
info "Checking other tools..."
for tool in ar as ld nm objdump ranlib strip; do
    TOOL_PATH="${TOOLCHAIN_PREFIX}/bin/${TARGET}-${tool}"
    if [ ! -x "${TOOL_PATH}" ]; then
        warning "Tool not found: ${TARGET}-${tool}"
    else
        success "Found: ${tool}"
    fi
done

# Test 7: Test compilation - C program
info "Testing C compilation..."
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

cat > "${TEMP_DIR}/test.c" << 'EOF'
#include <stdio.h>

int main(int argc, char *argv[]) {
    printf("Hello from %s!\n", argv[0]);
    return 0;
}
EOF

if "${GCC}" -c "${TEMP_DIR}/test.c" -o "${TEMP_DIR}/test.o" 2>&1; then
    success "C compilation successful"
else
    error "C compilation failed"
fi

# Test 8: Test compilation - C++ program
if [ -x "${GXX}" ]; then
    info "Testing C++ compilation..."
    cat > "${TEMP_DIR}/test.cpp" << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello from C++!" << std::endl;
    return 0;
}
EOF

    if "${GXX}" -c "${TEMP_DIR}/test.cpp" -o "${TEMP_DIR}/test_cpp.o" 2>&1; then
        success "C++ compilation successful"
    else
        warning "C++ compilation failed"
    fi
fi

# Test 9: Check library directories
info "Checking library directories..."
LIB_DIR="${TOOLCHAIN_PREFIX}/lib/gcc/${TARGET}"
if [ -d "${LIB_DIR}" ]; then
    GCC_VERSION=$(ls "${LIB_DIR}" | head -1)
    if [ -n "${GCC_VERSION}" ]; then
        info "GCC version: ${GCC_VERSION}"
        success "Library directory found"
    fi
else
    warning "Library directory not found: ${LIB_DIR}"
fi

# Test 10: Check include directories
info "Checking include directories..."
INCLUDE_DIR="${TOOLCHAIN_PREFIX}/lib/gcc/${TARGET}/${GCC_VERSION:-*}/include"
if ls ${INCLUDE_DIR} >/dev/null 2>&1; then
    success "Include directory found"
else
    warning "Include directory not found"
fi

# Test 11: Check target libraries
info "Checking target libraries..."
TARGET_LIB_DIR="${TOOLCHAIN_PREFIX}/${TARGET}/lib"
if [ -d "${TARGET_LIB_DIR}" ]; then
    success "Target library directory found"
    
    # Check for important libraries
    for lib in libc.a libm.a libgcc.a; do
        if find "${TARGET_LIB_DIR}" -name "${lib}" | grep -q .; then
            success "Found: ${lib}"
        else
            warning "Not found: ${lib}"
        fi
    done
else
    warning "Target library directory not found: ${TARGET_LIB_DIR}"
fi

# Test 12: Print compiler specs
info "GCC specs:"
"${GCC}" -dumpspecs 2>&1 | head -20

echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
success "All critical tests passed!"
echo ""
echo "To use this toolchain, add to your PATH:"
echo "  export PATH=${TOOLCHAIN_PREFIX}/bin:\$PATH"
echo ""
echo "Compile example:"
echo "  ${TARGET}-gcc -o hello hello.c"
echo ""
echo "For cross-compilation with sysroot:"
echo "  ${TARGET}-gcc --sysroot=/path/to/sysroot -o hello hello.c"
echo ""
