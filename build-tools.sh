#!/bin/bash
# Build static make and bash for OpenHarmony (OHOS)
# Uses stage1 cross-compiler to build native OHOS tools

set -e

# ============================================================================
# Configuration
# ============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Tool versions
MAKE_VERSION="${MAKE_VERSION:-4.4.1}"
OHOS_BASH_VERSION="${OHOS_BASH_VERSION:-5.2.32}"
NCURSES_VERSION="${NCURSES_VERSION:-6.4}"  # bash readline dependency

# Directories
STAGE1_PREFIX="${STAGE1_PREFIX:-${SCRIPT_DIR}/install}"
TOOLS_BUILD_DIR="${SCRIPT_DIR}/build-tools"
TOOLS_INSTALL_DIR="${TOOLS_INSTALL_DIR:-${SCRIPT_DIR}/install-tools}"
DOWNLOAD_DIR="${SCRIPT_DIR}/downloads"

# Target triplet
TARGET="${TARGET:-x86_64-linux-ohos}"

# Cross-compiler settings
CC="${STAGE1_PREFIX}/bin/${TARGET}-gcc"
CXX="${STAGE1_PREFIX}/bin/${TARGET}-g++"
AR="${STAGE1_PREFIX}/bin/${TARGET}-ar"
RANLIB="${STAGE1_PREFIX}/bin/${TARGET}-ranlib"
STRIP="${STAGE1_PREFIX}/bin/${TARGET}-strip"

# URLs
MAKE_URL="https://ftp.gnu.org/gnu/make/make-${MAKE_VERSION}.tar.gz"
BASH_URL="https://ftp.gnu.org/gnu/bash/bash-${OHOS_BASH_VERSION}.tar.gz"
NCURSES_URL="https://ftp.gnu.org/gnu/ncurses/ncurses-${NCURSES_VERSION}.tar.gz"

# Local config.sub with OHOS support
CONFIG_SUB="${SCRIPT_DIR}/config/config.sub"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# Helper Functions
# ============================================================================

msg() {
    echo -e "${GREEN}==>${NC} $1"
}

warn() {
    echo -e "${YELLOW}==> WARNING:${NC} $1"
}

error() {
    echo -e "${RED}==> ERROR:${NC} $1"
    exit 1
}

download() {
    local url="$1"
    local dest="$2"
    
    if [ -f "$dest" ]; then
        msg "Already downloaded: $(basename "$dest")"
        return 0
    fi
    
    msg "Downloading $(basename "$dest")..."
    wget -q --show-progress -O "$dest" "$url" || curl -L -o "$dest" "$url"
}

# Update config.sub to support OHOS
update_config_sub() {
    local src_dir="$1"
    
    if [ ! -f "$CONFIG_SUB" ]; then
        warn "Local config.sub not found at $CONFIG_SUB"
        return 1
    fi
    
    msg "Updating config.sub in $src_dir..."
    
    # Find and replace all config.sub files
    find "$src_dir" -name "config.sub" -type f | while read -r file; do
        if grep -q "ohos" "$file" 2>/dev/null; then
            msg "  $(basename $(dirname $file))/config.sub already has OHOS support"
        else
            cp "$CONFIG_SUB" "$file"
            msg "  Updated: $file"
        fi
    done
}

check_cross_compiler() {
    if [ ! -x "$CC" ]; then
        error "Cross-compiler not found: $CC
Please build stage1 first or set STAGE1_PREFIX"
    fi
    msg "Using cross-compiler: $CC"
    $CC --version | head -1
}

# ============================================================================
# Build Functions
# ============================================================================

build_make() {
    msg "Building GNU Make ${MAKE_VERSION} for ${TARGET}..."
    
    local src_dir="${TOOLS_BUILD_DIR}/make-${MAKE_VERSION}"
    local build_dir="${TOOLS_BUILD_DIR}/build-make"
    
    # Download
    download "$MAKE_URL" "${DOWNLOAD_DIR}/make-${MAKE_VERSION}.tar.gz"
    
    # Extract
    if [ ! -d "$src_dir" ]; then
        msg "Extracting make source..."
        tar -xzf "${DOWNLOAD_DIR}/make-${MAKE_VERSION}.tar.gz" -C "${TOOLS_BUILD_DIR}"
    fi
    
    # Update config.sub to support OHOS
    update_config_sub "$src_dir"
    
    # Fix gnulib compatibility issue with OHOS headers
    # The old K&R style declarations conflict with modern headers
    msg "Patching source for OHOS compatibility..."
    # Fix getenv declarations
    find "$src_dir" -name "*.c" -o -name "*.h" | xargs sed -i \
        -e 's/extern char \*getenv ();/extern char *getenv (const char *);/g' \
        -e 's/extern int getopt ();/extern int getopt (int, char *const*, const char *);/g' \
        2>/dev/null || true
    
    # Build
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    msg "Configuring make..."
    # Use -D_GNU_SOURCE to get proper function declarations
    CFLAGS="-O2 -static -D_GNU_SOURCE" \
    LDFLAGS="-static" \
    CC="$CC" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    "$src_dir/configure" \
        --host="${TARGET}" \
        --prefix="${TOOLS_INSTALL_DIR}" \
        --disable-nls \
        --disable-dependency-tracking \
        --without-guile
    
    msg "Compiling make..."
    make -j$(nproc)
    
    msg "Installing make..."
    make install
    
    # Strip binary
    "$STRIP" "${TOOLS_INSTALL_DIR}/bin/make" 2>/dev/null || true
    
    msg "Make built successfully!"
    file "${TOOLS_INSTALL_DIR}/bin/make"
    ls -lh "${TOOLS_INSTALL_DIR}/bin/make"
}

build_ncurses() {
    msg "Building ncurses ${NCURSES_VERSION} for ${TARGET} (bash dependency)..."
    
    local src_dir="${TOOLS_BUILD_DIR}/ncurses-${NCURSES_VERSION}"
    local build_dir="${TOOLS_BUILD_DIR}/build-ncurses"
    
    # Download
    download "$NCURSES_URL" "${DOWNLOAD_DIR}/ncurses-${NCURSES_VERSION}.tar.gz"
    
    # Extract
    if [ ! -d "$src_dir" ]; then
        msg "Extracting ncurses source..."
        tar -xzf "${DOWNLOAD_DIR}/ncurses-${NCURSES_VERSION}.tar.gz" -C "${TOOLS_BUILD_DIR}"
    fi
    
    # Update config.sub to support OHOS
    update_config_sub "$src_dir"
    
    # Build
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    msg "Configuring ncurses..."
    CFLAGS="-O2" \
    CC="$CC" \
    CXX="$CXX" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    "$src_dir/configure" \
        --host="${TARGET}" \
        --prefix="${TOOLS_INSTALL_DIR}" \
        --without-cxx \
        --without-cxx-binding \
        --without-ada \
        --without-manpages \
        --without-progs \
        --without-tests \
        --disable-database \
        --disable-termcap \
        --with-fallbacks=vt100,vt102,xterm,xterm-256color,linux \
        --enable-termcap \
        --enable-static \
        --disable-shared \
        --with-normal
    
    msg "Compiling ncurses..."
    make -j$(nproc)
    
    msg "Installing ncurses..."
    make install
    
    msg "ncurses built successfully!"
}

build_bash() {
    msg "Building Bash ${OHOS_BASH_VERSION} for ${TARGET}..."
    
    local src_dir="${TOOLS_BUILD_DIR}/bash-${OHOS_BASH_VERSION}"
    local build_dir="${TOOLS_BUILD_DIR}/build-bash"
    
    # Download
    download "$BASH_URL" "${DOWNLOAD_DIR}/bash-${OHOS_BASH_VERSION}.tar.gz"
    
    # Extract
    if [ ! -d "$src_dir" ]; then
        msg "Extracting bash source..."
        tar -xzf "${DOWNLOAD_DIR}/bash-${OHOS_BASH_VERSION}.tar.gz" -C "${TOOLS_BUILD_DIR}"
    fi
    
    # Update config.sub to support OHOS
    update_config_sub "$src_dir"
    
    # Build ncurses first (for readline)
    if [ ! -f "${TOOLS_INSTALL_DIR}/lib/libncurses.a" ]; then
        build_ncurses
    fi
    
    # Build
    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    msg "Configuring bash..."
    
    # Create config.cache for cross-compilation
    cat > config.cache << 'EOF'
ac_cv_func_mmap_fixed_mapped=yes
ac_cv_func_strcoll_works=yes
ac_cv_func_working_mktime=yes
bash_cv_func_sigsetjmp=present
bash_cv_getcwd_malloc=yes
bash_cv_job_control_missing=present
bash_cv_printf_a_format=yes
bash_cv_sys_named_pipes=present
bash_cv_ulimit_maxfds=yes
bash_cv_under_sys_siglist=yes
bash_cv_unusable_rtsigs=no
gt_cv_int_divbyzero_sigfpe=yes
EOF
    
    # Use -Wno-error to allow warnings, and -std=gnu89 for K&R style code
    CFLAGS="-O2 -static -I${TOOLS_INSTALL_DIR}/include -I${TOOLS_INSTALL_DIR}/include/ncurses -std=gnu89 -Wno-error" \
    LDFLAGS="-static -L${TOOLS_INSTALL_DIR}/lib" \
    LIBS="-lncurses" \
    CC="$CC" \
    AR="$AR" \
    RANLIB="$RANLIB" \
    "$src_dir/configure" \
        --host="${TARGET}" \
        --prefix="${TOOLS_INSTALL_DIR}" \
        --cache-file=config.cache \
        --enable-static-link \
        --without-bash-malloc \
        --disable-nls \
        --disable-rpath \
        --enable-readline \
        --with-curses \
        --with-installed-readline=no
    
    msg "Compiling bash..."
    make -j$(nproc)
    
    msg "Installing bash..."
    make install
    
    # Strip binary
    "$STRIP" "${TOOLS_INSTALL_DIR}/bin/bash" 2>/dev/null || true
    
    msg "Bash built successfully!"
    file "${TOOLS_INSTALL_DIR}/bin/bash"
    ls -lh "${TOOLS_INSTALL_DIR}/bin/bash"
}

build_all() {
    msg "Building all tools for ${TARGET}..."
    build_make
    build_bash
    
    msg ""
    msg "============================================"
    msg "All tools built successfully!"
    msg "============================================"
    msg ""
    msg "Tools installed to: ${TOOLS_INSTALL_DIR}"
    msg ""
    msg "Binaries:"
    ls -lh "${TOOLS_INSTALL_DIR}/bin/"
    msg ""
    msg "To use in OHOS container:"
    msg "  docker cp ${TOOLS_INSTALL_DIR}/bin/make CONTAINER:/bin/"
    msg "  docker cp ${TOOLS_INSTALL_DIR}/bin/bash CONTAINER:/bin/"
}

clean() {
    msg "Cleaning build directories..."
    rm -rf "${TOOLS_BUILD_DIR}"
    msg "Clean complete."
}

show_help() {
    cat << EOF
Usage: $0 [OPTIONS] COMMAND

Build static tools for OpenHarmony using cross-compiler.

Commands:
  all       Build all tools (make, bash)
  make      Build GNU Make only
  bash      Build Bash only
  clean     Clean build directories

Options:
  --target=TRIPLET    Target triplet (default: x86_64-linux-ohos)
  --stage1=PATH       Path to stage1 cross-compiler (default: ./install)
  --prefix=PATH       Installation prefix (default: ./install-tools)
  -h, --help          Show this help

Examples:
  $0 all
  $0 --target=aarch64-linux-ohos all
  $0 --stage1=/path/to/cross-compiler make

EOF
}

# ============================================================================
# Main
# ============================================================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --target=*)
            TARGET="${1#*=}"
            CC="${STAGE1_PREFIX}/bin/${TARGET}-gcc"
            CXX="${STAGE1_PREFIX}/bin/${TARGET}-g++"
            AR="${STAGE1_PREFIX}/bin/${TARGET}-ar"
            RANLIB="${STAGE1_PREFIX}/bin/${TARGET}-ranlib"
            STRIP="${STAGE1_PREFIX}/bin/${TARGET}-strip"
            shift
            ;;
        --stage1=*)
            STAGE1_PREFIX="$(cd "${1#*=}" && pwd)"
            CC="${STAGE1_PREFIX}/bin/${TARGET}-gcc"
            CXX="${STAGE1_PREFIX}/bin/${TARGET}-g++"
            AR="${STAGE1_PREFIX}/bin/${TARGET}-ar"
            RANLIB="${STAGE1_PREFIX}/bin/${TARGET}-ranlib"
            STRIP="${STAGE1_PREFIX}/bin/${TARGET}-strip"
            shift
            ;;
        --prefix=*)
            TOOLS_INSTALL_DIR="$(cd "${1#*=}" 2>/dev/null && pwd || echo "${1#*=}")"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        all|make|bash|clean)
            COMMAND="$1"
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

COMMAND="${COMMAND:-all}"

# Create directories
mkdir -p "${TOOLS_BUILD_DIR}" "${TOOLS_INSTALL_DIR}" "${DOWNLOAD_DIR}"

# Check cross-compiler
check_cross_compiler

# Execute command
case "$COMMAND" in
    all)
        build_all
        ;;
    make)
        build_make
        ;;
    bash)
        build_bash
        ;;
    clean)
        clean
        ;;
    *)
        error "Unknown command: $COMMAND"
        ;;
esac

msg "Done!"
