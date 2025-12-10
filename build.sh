#!/bin/bash
# GCC Build Script for OpenHarmony (OHOS) Target
# Based on Alpine Linux APKBUILD
# Copyright (C) 2024 OpenHarmony Project

set -e

# ============================================================================
# Configuration Variables
# ============================================================================

# GCC Version
GCC_VERSION="15.2.0"
GCC_MAJOR_VERSION="${GCC_VERSION%%.*}"

# Build directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/gcc-${GCC_VERSION}"
BUILD_DIR="${SCRIPT_DIR}/build-ohos"
INSTALL_PREFIX="${INSTALL_PREFIX:-${SCRIPT_DIR}/install}"
SYSROOT="${SYSROOT:-}"

# Binutils configuration
BINUTILS_VERSION="${BINUTILS_VERSION:-2.43}"
BINUTILS_SOURCE_DIR="${SCRIPT_DIR}/binutils-${BINUTILS_VERSION}"
BINUTILS_BUILD_DIR="${SCRIPT_DIR}/build-binutils"
BINUTILS_INSTALL_PREFIX="${BINUTILS_INSTALL_PREFIX:-${INSTALL_PREFIX}}"

# Target configuration
DEFAULT_CBUILD="$(gcc -dumpmachine)"
CBUILD="${CBUILD:-${DEFAULT_CBUILD}}"
CHOST="${CHOST:-}"
CTARGET="${CTARGET:-aarch64-linux-ohos}"

# Extract architecture from target triplet
case "${CTARGET}" in
    aarch64-*)
        CTARGET_ARCH="aarch64"
        ARCH_CONFIGURE="--with-arch=armv8-a --with-abi=lp64"
        ;;
    arm*hf-*)
        CTARGET_ARCH="armv7"
        ARCH_CONFIGURE="--with-arch=armv7-a --with-tune=generic-armv7-a --with-fpu=vfpv3-d16 --with-float=hard --with-abi=aapcs-linux --with-mode=thumb"
        ;;
    arm*-*)
        CTARGET_ARCH="arm"
        ARCH_CONFIGURE="--with-arch=armv5te --with-tune=arm926ej-s --with-float=soft --with-abi=aapcs-linux"
        ;;
    x86_64-*)
        CTARGET_ARCH="x86_64"
        ARCH_CONFIGURE=""
        SANITIZER_CONFIGURE="--enable-libsanitizer"
        ;;
    i?86-*)
        CTARGET_ARCH="x86"
        ARCH_CONFIGURE="--with-arch=i486 --with-tune=generic --enable-cld"
        ;;
    riscv64-*)
        CTARGET_ARCH="riscv64"
        ARCH_CONFIGURE="--with-arch=rv64gc --with-abi=lp64d --enable-autolink-libatomic"
        ;;
    mips64el-*)
        CTARGET_ARCH="mips64el"
        ARCH_CONFIGURE="--with-arch=mips3 --with-tune=mips64 --with-mips-plt --with-float=soft --with-abi=64"
        ;;
    mips64-*)
        CTARGET_ARCH="mips64"
        ARCH_CONFIGURE="--with-arch=mips3 --with-tune=mips64 --with-mips-plt --with-float=soft --with-abi=64"
        ;;
    mipsel-*)
        CTARGET_ARCH="mipsel"
        ARCH_CONFIGURE="--with-arch=mips32 --with-mips-plt --with-float=soft --with-abi=32"
        ;;
    mips-*)
        CTARGET_ARCH="mips"
        ARCH_CONFIGURE="--with-arch=mips32 --with-mips-plt --with-float=soft --with-abi=32"
        ;;
    *)
        echo "Error: Unsupported target architecture: ${CTARGET}"
        exit 1
        ;;
esac

# Default sanitizer config (disabled for most architectures)
SANITIZER_CONFIGURE="${SANITIZER_CONFIGURE:---disable-libsanitizer}"

# Hash style configuration
case "${CTARGET_ARCH}" in
    mips*) HASH_STYLE_CONFIGURE="--with-linker-hash-style=sysv" ;;
    *)     HASH_STYLE_CONFIGURE="--with-linker-hash-style=gnu" ;;
esac

# Language support
LANG_CXX="${LANG_CXX:-yes}"
LANG_D="${LANG_D:-no}"
LANG_OBJC="${LANG_OBJC:-no}"
LANG_GO="${LANG_GO:-no}"
LANG_FORTRAN="${LANG_FORTRAN:-no}"
LANG_ADA="${LANG_ADA:-no}"
LANG_JIT="${LANG_JIT:-no}"

# Build languages list
LANGUAGES="c"
[ "${LANG_CXX}" = "yes" ] && LANGUAGES="${LANGUAGES},c++"
[ "${LANG_D}" = "yes" ] && LANGUAGES="${LANGUAGES},d"
[ "${LANG_OBJC}" = "yes" ] && LANGUAGES="${LANGUAGES},objc"
[ "${LANG_GO}" = "yes" ] && LANGUAGES="${LANGUAGES},go"
[ "${LANG_FORTRAN}" = "yes" ] && LANGUAGES="${LANGUAGES},fortran"
[ "${LANG_ADA}" = "yes" ] && LANGUAGES="${LANGUAGES},ada"
[ "${LANG_JIT}" = "yes" ] && LANGUAGES="${LANGUAGES},jit"

# Library features
LIBGOMP="${LIBGOMP:-yes}"
LIBATOMIC="${LIBATOMIC:-yes}"
LIBITM="${LIBITM:-yes}"
LIBQUADMATH="${LIBQUADMATH:-no}"

# Disable libitm for certain architectures
case "${CTARGET_ARCH}" in
    arm*|mips*|riscv64) LIBITM="no" ;;
esac

# Quadmath support (x86/x86_64/ppc64le only)
case "${CTARGET_ARCH}" in
    x86|x86_64|ppc64le) LIBQUADMATH="yes" ;;
esac

# Build configuration
BOOTSTRAP_CONFIGURE="--enable-shared --enable-threads --enable-tls"
[ "${LIBGOMP}" = "no" ] && BOOTSTRAP_CONFIGURE="${BOOTSTRAP_CONFIGURE} --disable-libgomp"
[ "${LIBATOMIC}" = "no" ] && BOOTSTRAP_CONFIGURE="${BOOTSTRAP_CONFIGURE} --disable-libatomic"
[ "${LIBITM}" = "no" ] && BOOTSTRAP_CONFIGURE="${BOOTSTRAP_CONFIGURE} --disable-libitm"
[ "${LIBQUADMATH}" = "no" ] && ARCH_CONFIGURE="${ARCH_CONFIGURE} --disable-libquadmath"

# Cross-compilation configuration will be resolved during configure phase

# Parallel build
JOBS="${JOBS:-$(nproc)}"

# ============================================================================
# Helper Functions
# ============================================================================

msg() {
    echo "===> $*"
}

error() {
    echo "ERROR: $*" >&2
    exit 1
}

# ============================================================================
# Build Steps
# ============================================================================

prepare_binutils() {
    msg "Preparing binutils ${BINUTILS_VERSION} source directory..."

    if [ ! -d "${BINUTILS_SOURCE_DIR}" ]; then
        msg "Downloading binutils ${BINUTILS_VERSION}..."
        local tarball="binutils-${BINUTILS_VERSION}.tar.xz"
        if [ ! -f "${tarball}" ]; then
            wget "https://ftp.gnu.org/gnu/binutils/${tarball}" || \
                error "Failed to download binutils source"
        fi

        msg "Extracting binutils source..."
        tar -xf "${tarball}" || error "Failed to extract binutils source"
    fi

    msg "Applying binutils patches..."
    cd "${BINUTILS_SOURCE_DIR}"

    for patch in "${SCRIPT_DIR}"/binutils-patches/*.patch; do
        [ -f "${patch}" ] || continue
        msg "Applying $(basename "${patch}")..."
        patch -p1 -N -i "${patch}" || msg "Patch $(basename "${patch}") already applied or failed"
    done

    cd "${SCRIPT_DIR}"
}

build_binutils() {
    prepare_binutils

    msg "Configuring binutils for ${CTARGET}..."
    mkdir -p "${BINUTILS_BUILD_DIR}"
    cd "${BINUTILS_BUILD_DIR}"

    local configure_args=(
        "${BINUTILS_SOURCE_DIR}/configure"
        "--prefix=${BINUTILS_INSTALL_PREFIX}"
        "--build=${CBUILD}"
        "--host=${CHOST}"
        "--target=${CTARGET}"
        "--disable-nls"
        "--disable-werror"
    )

    if [ -n "${SYSROOT}" ]; then
        configure_args+=("--with-sysroot=${SYSROOT}")
    fi

    "${configure_args[@]}" || error "Binutils configuration failed"

    make -j"${JOBS}" MAKEINFO=true || error "Binutils build failed"
    make install DESTDIR="${DESTDIR:-}" MAKEINFO=true || error "Binutils install failed"

    cd "${SCRIPT_DIR}"
}

ensure_binutils() {
    local expected_ld="${BINUTILS_INSTALL_PREFIX}/bin/${CTARGET}-ld"
    if [ ! -x "${expected_ld}" ]; then
        msg "Binutils not found at ${expected_ld}; building binutils..."
        build_binutils
    else
        msg "Using existing binutils from ${BINUTILS_INSTALL_PREFIX}"
    fi
}

apply_sysroot_patches() {
    if [ -d "${SCRIPT_DIR}/sysroot-patches" ]; then
        msg "Applying sysroot patches..."
        for patch in "${SCRIPT_DIR}"/sysroot-patches/*.patch; do
            [ -f "${patch}" ] || continue
            msg "Applying $(basename "${patch}")..."
            patch -d "${SCRIPT_DIR}" -p0 -N -i "${patch}" || msg "Patch $(basename "${patch}") already applied or failed"
        done
    fi
}

prepare_gcc() {
    msg "Preparing GCC source directory..."

    # Download GCC source if not present
    if [ ! -d "${SOURCE_DIR}" ]; then
        msg "Downloading GCC ${GCC_VERSION}..."
        local tarball="gcc-${GCC_VERSION}.tar.xz"
        if [ ! -f "${tarball}" ]; then
            wget "https://gcc.gnu.org/pub/gcc/releases/gcc-${GCC_VERSION}/${tarball}" || \
                error "Failed to download GCC source"
        fi

        msg "Extracting GCC source..."
        tar -xf "${tarball}" || error "Failed to extract GCC source"
    fi

    # Apply patches
    msg "Applying GCC patches..."
    cd "${SOURCE_DIR}"

    # Apply OHOS patch first
    if [ -f "${SCRIPT_DIR}/gcc-patches/0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch" ]; then
        patch -p1 -N -i "${SCRIPT_DIR}/gcc-patches/0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch" || \
            msg "OHOS patch already applied or failed"
    fi

    # Apply other patches
    for patch in "${SCRIPT_DIR}"/gcc-patches/*.patch; do
        [ -f "${patch}" ] || continue
        [[ "${patch}" =~ "0001-Add-OpenHarmony-OHOS" ]] && continue

        msg "Applying $(basename "${patch}")..."
        patch -p1 -N -i "${patch}" || msg "Patch $(basename "${patch}") already applied or failed"
    done

    echo "${GCC_VERSION}" > gcc/BASE-VER

    cd "${SCRIPT_DIR}"
}

configure_gcc() {
    ensure_binutils
    apply_sysroot_patches
    prepare_gcc

    msg "Configuring GCC ${GCC_VERSION} for ${CTARGET}..."

    if [ -d "${BINUTILS_INSTALL_PREFIX}/bin" ]; then
        export PATH="${BINUTILS_INSTALL_PREFIX}/bin:${PATH}"
    fi

    local extra_binutils_flags=""
    local as_path="${BINUTILS_INSTALL_PREFIX}/bin/${CTARGET}-as"
    local ld_path="${BINUTILS_INSTALL_PREFIX}/bin/${CTARGET}-ld"
    [ -x "${as_path}" ] && extra_binutils_flags+=" --with-as=${as_path}"
    [ -x "${ld_path}" ] && extra_binutils_flags+=" --with-ld=${ld_path}"

    # Create build directory
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    
    # Set build environment
    export libat_cv_have_ifunc=no
    
    # Configure flags for different build scenarios
    if [ "${CHOST}" != "${CTARGET}" ]; then
        # Cross-compilation: disable format-security warning
        export CFLAGS="${CFLAGS:-} -g0 -O2"
        export CXXFLAGS="${CXXFLAGS:-} -g0 -O2"
        export CFLAGS_FOR_TARGET=" "
        export CXXFLAGS_FOR_TARGET=" "
        export LDFLAGS_FOR_TARGET=" "
    else
        # Native build
        export CFLAGS="${CFLAGS:-} -g0 -O2"
        export CXXFLAGS="${CXXFLAGS:-} -g0 -O2"
        export CFLAGS_FOR_TARGET="${CFLAGS}"
        export CXXFLAGS_FOR_TARGET="${CXXFLAGS}"
        export LDFLAGS_FOR_TARGET="${LDFLAGS:-}"
        export BOOT_CFLAGS="${CFLAGS}"
        export BOOT_LDFLAGS="${LDFLAGS:-}"
    fi
    
    msg "Build configuration:"
    echo "  CBUILD=${CBUILD}"
    echo "  CHOST=${CHOST}"
    echo "  CTARGET=${CTARGET}"
    echo "  CTARGET_ARCH=${CTARGET_ARCH}"
    echo "  LANGUAGES=${LANGUAGES}"
    echo "  INSTALL_PREFIX=${INSTALL_PREFIX}"
    echo "  SYSROOT=${SYSROOT}"
    echo "  CROSS_COMPILE=${CROSS_COMPILE}"
    echo ""

    if [ -n "${CROSS_COMPILE}" ]; then
        export AR_FOR_TARGET="${AR_FOR_TARGET:-${CROSS_COMPILE}ar}"
        export AS_FOR_TARGET="${AS_FOR_TARGET:-${CROSS_COMPILE}as}"
        export LD_FOR_TARGET="${LD_FOR_TARGET:-${CROSS_COMPILE}ld}"
        export NM_FOR_TARGET="${NM_FOR_TARGET:-${CROSS_COMPILE}nm}"
        export OBJDUMP_FOR_TARGET="${OBJDUMP_FOR_TARGET:-${CROSS_COMPILE}objdump}"
        export OBJCOPY_FOR_TARGET="${OBJCOPY_FOR_TARGET:-${CROSS_COMPILE}objcopy}"
        export RANLIB_FOR_TARGET="${RANLIB_FOR_TARGET:-${CROSS_COMPILE}ranlib}"
        export STRIP_FOR_TARGET="${STRIP_FOR_TARGET:-${CROSS_COMPILE}strip}"
    fi
    
    # Configure GCC
    local cross_configure=()
    if [ "${CBUILD}" != "${CHOST}" ] || [ "${CHOST}" != "${CTARGET}" ]; then
        cross_configure+=("--disable-bootstrap")
    fi
    if [ "${CHOST}" != "${CTARGET}" ] && [ -n "${SYSROOT}" ]; then
        cross_configure+=("--with-sysroot=${SYSROOT}")
    fi

    "${SOURCE_DIR}/configure" \
        --prefix="${INSTALL_PREFIX}" \
        --mandir="${INSTALL_PREFIX}/share/man" \
        --infodir="${INSTALL_PREFIX}/share/info" \
        --build="${CBUILD}" \
        --host="${CHOST}" \
        --target="${CTARGET}" \
        --with-pkgversion="OHOS GCC ${GCC_VERSION}" \
        --with-bugurl="https://gitee.com/openharmony" \
        --with-system-zlib \
        --enable-checking=release \
        --enable-languages="${LANGUAGES}" \
        --enable-__cxa_atexit \
        --enable-default-pie \
        --enable-default-ssp \
        --enable-linker-build-id \
        --enable-link-serialization=2 \
        --disable-cet \
        --disable-fixed-point \
        --disable-libstdcxx-pch \
        --disable-multilib \
        --disable-nls \
        --disable-werror \
        --disable-symvers \
        --disable-libssp \
        ${ARCH_CONFIGURE} \
        ${SANITIZER_CONFIGURE} \
        "${cross_configure[@]}" \
        ${BOOTSTRAP_CONFIGURE} \
        ${HASH_STYLE_CONFIGURE} \
        ${extra_binutils_flags} \
        ${EXTRA_CONFIGURE_FLAGS:-} \
        || error "Configuration failed"
}

build_gcc() {
    msg "Building GCC..."
    cd "${BUILD_DIR}"
    
    make -j"${JOBS}" || error "Build failed"
}

install_gcc() {
    msg "Installing GCC to ${INSTALL_PREFIX}..."
    cd "${BUILD_DIR}"
    
    make install DESTDIR="${DESTDIR:-}" || error "Installation failed"
    
    local real_prefix="${DESTDIR:-}${INSTALL_PREFIX}"
    mkdir -p "${real_prefix}/bin"

    # Create convenient compiler symlinks inside install prefix
    if [ "${CHOST}" = "${CTARGET}" ]; then
        ln -sf gcc "${real_prefix}/bin/cc"
    fi
    ln -sf "${CTARGET}-gcc" "${real_prefix}/bin/${CTARGET}-cc"
    
    msg "GCC installation complete"
}

clean() {
    msg "Cleaning build directories..."
    rm -rf "${BUILD_DIR}" "${BINUTILS_BUILD_DIR}"
}

# ============================================================================
# Main Script
# ============================================================================

show_help() {
    cat <<EOF
GCC Build Script for OpenHarmony (OHOS) Target

Usage: $0 [OPTIONS] [COMMAND]

Commands:
    prepare       Download sources and apply patches for binutils and GCC
    binutils      Build and install binutils only
    configure     Ensure binutils exist and configure GCC
    build         Build GCC
    install       Install GCC
    all           Run full pipeline (binutils + GCC)
    clean         Clean build directories

Options:
  --target=TARGET           Set target triplet (default: aarch64-linux-ohos)
    --host=HOST               Set host triplet (default: auto-detected)
    --build=BUILD             Set build triplet (default: auto-detected)
  --prefix=PREFIX           Set installation prefix (default: ./install)
  --sysroot=SYSROOT         Set sysroot path for cross-compilation
  --jobs=N                  Number of parallel jobs (default: $(nproc))
  --enable-languages=LIST   Comma-separated language list (default: c,c++)
  --help                    Show this help message

Environment Variables:
  CTARGET                   Target triplet
    CHOST                     Host triplet
    CBUILD                    Build triplet
  INSTALL_PREFIX            Installation prefix
    BINUTILS_VERSION          Binutils version (default: ${BINUTILS_VERSION})
    BINUTILS_INSTALL_PREFIX   Binutils installation prefix (default: same as INSTALL_PREFIX)
  SYSROOT                   Sysroot path
  JOBS                      Number of parallel jobs
    CROSS_COMPILE             Cross prefix override (default: target- when cross compiling)
  LANG_*                    Enable/disable specific languages (yes/no)

Examples:
  # Build for AArch64 OHOS
  $0 --target=aarch64-linux-ohos --prefix=/opt/ohos-gcc

  # Build for ARM OHOS with custom sysroot
  $0 --target=arm-linux-ohos --sysroot=/path/to/sysroot

  # Build with only C and C++ support
  $0 --enable-languages=c,c++

EOF
}

# Parse command line arguments
COMMAND="all"
while [ $# -gt 0 ]; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        --target=*)
            CTARGET="${1#*=}"
            ;;
        --host=*)
            CHOST="${1#*=}"
            ;;
        --build=*)
            CBUILD="${1#*=}"
            ;;
        --prefix=*)
            INSTALL_PREFIX="${1#*=}"
            ;;
        --sysroot=*)
            SYSROOT="${1#*=}"
            ;;
        --jobs=*)
            JOBS="${1#*=}"
            ;;
        --enable-languages=*)
            LANGUAGES="${1#*=}"
            ;;
        prepare|binutils|configure|build|install|all|clean)
            COMMAND="$1"
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
    shift
done

# Normalize sysroot path to absolute form if provided
if [ -n "${SYSROOT}" ]; then
    if ! resolved_sysroot=$(readlink -f "${SYSROOT}"); then
        error "Failed to resolve sysroot path: ${SYSROOT}"
    fi
    SYSROOT="${resolved_sysroot}"
fi

# Resolve defaults that depend on parsed values
CHOST="${CHOST:-${CBUILD}}"

# Determine cross-compilation context after parsing options
if [ -z "${CROSS_COMPILE:-}" ]; then
    if [ "${CHOST}" != "${CTARGET}" ]; then
        CROSS_COMPILE="${CTARGET}-"
    else
        CROSS_COMPILE=""
    fi
fi
export CROSS_COMPILE

IS_NATIVE_BUILD=0
if [ "${CHOST}" = "${CTARGET}" ]; then
    IS_NATIVE_BUILD=1
fi

# Execute command
case "${COMMAND}" in
    prepare)
        prepare_binutils
        apply_sysroot_patches
        prepare_gcc
        ;;
    binutils)
        build_binutils
        ;;
    configure)
        configure_gcc
        ;;
    build)
        build_gcc
        ;;
    install)
        install_gcc
        ;;
    clean)
        clean
        ;;
    all)
        build_binutils
        configure_gcc
        build_gcc
        install_gcc
        ;;
    *)
        error "Unknown command: ${COMMAND}"
        ;;
esac

msg "Done!"