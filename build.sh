#!/bin/bash
# GCC Build Script for OpenHarmony (OHOS) Target
# Based on Alpine Linux APKBUILD
# Copyright (C) 2024 OpenHarmony Project

set -e

# CRITICAL FIX: Disable shell aliases/functions for diff and use absolute path
# Some shell configurations define diff() with --color which breaks
# autoconf's config.status script that uses diff for file comparison
# Also ensure we use /bin/diff, not any custom diff in PATH
unset -f diff
alias diff='/bin/diff'
export DIFF='/bin/diff'
export PATH="/bin:/usr/bin:/usr/local/bin:${PATH}"

# ============================================================================
# Configuration Variables
# ============================================================================

# GCC Version
GCC_VERSION="15.2.0"
# shellcheck disable=SC2034  # Reserved for future use
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
# BINUTILS_INSTALL_PREFIX is set after command line parsing to use the correct INSTALL_PREFIX

# Stage 2 (Canadian Cross) configuration
# When building native OHOS toolchain, we need a stage 1 cross-compiler
# STAGE1_PREFIX points to the previously built cross-compiler
STAGE1_PREFIX="${STAGE1_PREFIX:-}"

# Stage 3 (Native bootstrap) configuration
# When building on OHOS itself, we need a stage 2 native compiler
# STAGE2_PREFIX points to the previously built native OHOS compiler
STAGE2_PREFIX="${STAGE2_PREFIX:-}"

# NDK configuration
NDK_URL="${NDK_URL:-https://cidownload.openharmony.cn/version/Daily_Version/LLVM-19/20260114_061434/version-Daily_Version-LLVM-19-20260114_061434-LLVM-19.tar.gz}"
NDK_DIR="${SCRIPT_DIR}/ndk"
NDK_SYSROOT_DIR="${NDK_DIR}/sysroot"

# Target configuration
DEFAULT_CBUILD="$(gcc -dumpmachine)"
CBUILD="${CBUILD:-${DEFAULT_CBUILD}}"
CHOST="${CHOST:-}"
CTARGET="${CTARGET:-aarch64-linux-ohos}"

# Function to setup target-specific configuration
# This is called after command line parsing to ensure --target is respected
setup_target_config() {
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

    # Disable libitm for certain architectures
    case "${CTARGET_ARCH}" in
        arm*|mips*|riscv64) LIBITM="no" ;;
    esac

    # Quadmath support (x86/x86_64/ppc64le only) - disabled for cross-compilation
    case "${CTARGET_ARCH}" in
        x86|x86_64|ppc64le) LIBQUADMATH="no" ;;
    esac

    # Rebuild BOOTSTRAP_CONFIGURE with updated library settings
    BOOTSTRAP_CONFIGURE="--enable-shared --enable-threads --enable-tls"
    [ "${LIBGOMP}" = "no" ] && BOOTSTRAP_CONFIGURE="${BOOTSTRAP_CONFIGURE} --disable-libgomp"
    [ "${LIBATOMIC}" = "no" ] && BOOTSTRAP_CONFIGURE="${BOOTSTRAP_CONFIGURE} --disable-libatomic"
    [ "${LIBITM}" = "no" ] && BOOTSTRAP_CONFIGURE="${BOOTSTRAP_CONFIGURE} --disable-libitm"
    [ "${LIBQUADMATH}" = "no" ] && ARCH_CONFIGURE="${ARCH_CONFIGURE} --disable-libquadmath"
}

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
# Note: In cross-compilation, these libraries require link tests which fail early
# when GCC is not fully bootstrapped. Disable them by default for OHOS.
LIBGOMP="${LIBGOMP:-no}"
LIBATOMIC="${LIBATOMIC:-no}"
LIBITM="${LIBITM:-no}"
LIBQUADMATH="${LIBQUADMATH:-no}"

# Cross-compilation configuration will be resolved during configure phase
# Build types:
#   Stage 1 (cross):     CBUILD=host, CHOST=host,   CTARGET=ohos  (cross-compiler)
#   Stage 2 (Canadian):  CBUILD=host, CHOST=ohos,   CTARGET=ohos  (native compiler)
# Stage 2 requires STAGE1_PREFIX pointing to a working stage 1 cross-compiler

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

# Normalize a path to absolute form
# Usage: normalized=$(normalize_path "/some/path" [must_exist])
# If must_exist is "true", uses readlink -f (path must exist)
# Otherwise uses manual conversion (path can be non-existent)
normalize_path() {
    local path="$1"
    local must_exist="${2:-false}"
    
    [ -z "${path}" ] && return 0
    
    if [ "${must_exist}" = "true" ]; then
        readlink -f "${path}" || return 1
    else
        # Convert to absolute path manually (works with BusyBox)
        # Don't use realpath -m as BusyBox doesn't support it
        case "${path}" in
            /*) echo "${path}" ;;
            *)  echo "${PWD}/${path}" ;;
        esac
    fi
}

# Generic function to apply patches to a directory
# Usage: apply_patches_to_dir <name> <target_dir> <patches_dir>
apply_patches_to_dir() {
    local name="$1"
    local target_dir="$2"
    local patches_dir="$3"
    
    if [ ! -d "${target_dir}" ]; then
        msg "${name} directory not found, skipping patches"
        return 0
    fi
    
    if [ ! -d "${patches_dir}" ]; then
        return 0
    fi
    
    local real_target_dir
    real_target_dir=$(readlink -f "${target_dir}")
    
    msg "Applying ${name} patches for OHOS support..."
    
    for patch in "${patches_dir}"/*.patch; do
        [ -f "${patch}" ] || continue
        msg "Applying $(basename "${patch}") to ${name}..."
        cd "${real_target_dir}"
        patch -p0 -N -i "${patch}" 2>/dev/null || msg "Patch $(basename "${patch}") already applied or failed"
        cd "${SCRIPT_DIR}"
    done
}

# Check if this is a Canadian Cross build (stage 2)
is_canadian_cross() {
    [ "${CBUILD}" != "${CHOST}" ] && [ "${CHOST}" = "${CTARGET}" ]
}

# Check if this is a native OHOS build (stage 3)
# All three triplets are the same and are OHOS targets
is_native_ohos_build() {
    [ "${CBUILD}" = "${CHOST}" ] && [ "${CHOST}" = "${CTARGET}" ] && [[ "${CTARGET}" == *-linux-ohos ]]
}

# Verify stage 1 toolchain exists and is functional
check_stage1_toolchain() {
    if [ -z "${STAGE1_PREFIX}" ]; then
        error "STAGE1_PREFIX not set. Stage 2 build requires a stage 1 cross-compiler.
Use --stage1=/path/to/stage1/install to specify it."
    fi

    msg "Checking stage 1 toolchain at ${STAGE1_PREFIX}..."

    local cc="${STAGE1_PREFIX}/bin/${CTARGET}-gcc"
    local cxx="${STAGE1_PREFIX}/bin/${CTARGET}-g++"
    local ar="${STAGE1_PREFIX}/bin/${CTARGET}-ar"
    local as="${STAGE1_PREFIX}/bin/${CTARGET}-as"
    local ld="${STAGE1_PREFIX}/bin/${CTARGET}-ld"

    for tool in "${cc}" "${cxx}" "${ar}" "${as}" "${ld}"; do
        if [ ! -x "${tool}" ]; then
            error "Stage 1 tool not found: ${tool}
Make sure stage 1 cross-compiler is properly installed at ${STAGE1_PREFIX}"
        fi
    done

    msg "Stage 1 toolchain verified: $("${cc}" --version | head -1)"
}

# Verify stage 2 toolchain exists and is functional
check_stage2_toolchain() {
    if [ -z "${STAGE2_PREFIX}" ]; then
        error "STAGE2_PREFIX not set. Stage 3 build requires a stage 2 native compiler.
Use --stage2=/path/to/stage2/install to specify it."
    fi

    msg "Checking stage 2 toolchain at ${STAGE2_PREFIX}..."

    # Handle STAGE2_PREFIX=/ to avoid double slashes like //bin/gcc
    local prefix_bin
    if [ "${STAGE2_PREFIX}" = "/" ]; then
        prefix_bin="/bin"
    else
        prefix_bin="${STAGE2_PREFIX}/bin"
    fi

    # Stage 2 produces native tools, check for both prefixed and unprefixed names
    local cc="${prefix_bin}/gcc"
    local cxx="${prefix_bin}/g++"
    local ar="${prefix_bin}/ar"
    local as="${prefix_bin}/as"
    local ld="${prefix_bin}/ld"

    # Fall back to target-prefixed names if unprefixed not found
    [ ! -x "${cc}" ] && cc="${prefix_bin}/${CTARGET}-gcc"
    [ ! -x "${cxx}" ] && cxx="${prefix_bin}/${CTARGET}-g++"
    [ ! -x "${ar}" ] && ar="${prefix_bin}/${CTARGET}-ar"
    [ ! -x "${as}" ] && as="${prefix_bin}/${CTARGET}-as"
    [ ! -x "${ld}" ] && ld="${prefix_bin}/${CTARGET}-ld"

    for tool in "${cc}" "${cxx}" "${ar}" "${as}" "${ld}"; do
        if [ ! -x "${tool}" ]; then
            error "Stage 2 tool not found: ${tool}
Make sure stage 2 native compiler is properly installed at ${STAGE2_PREFIX}"
        fi
    done

    msg "Stage 2 toolchain verified: $("${cc}" --version | head -1)"
}

# Setup environment for Canadian Cross build (stage 2)
setup_canadian_cross_env() {
    msg "Setting up Canadian Cross (stage 2) build environment..."

    # Add stage 1 toolchain to PATH first, so tools can be found by name
    export PATH="${STAGE1_PREFIX}/bin:${PATH}"

    # Use stage 1 cross-compiler as the host compiler
    # IMPORTANT: Use full paths to avoid picking up wrong binaries from install prefix
    # when install-stage2/bin already contains old OHOS native binaries
    export CC="${STAGE1_PREFIX}/bin/${CTARGET}-gcc"
    export CXX="${STAGE1_PREFIX}/bin/${CTARGET}-g++"
    export AR="${STAGE1_PREFIX}/bin/${CTARGET}-ar"
    export AS="${STAGE1_PREFIX}/bin/${CTARGET}-as"
    export LD="${STAGE1_PREFIX}/bin/${CTARGET}-ld"
    export NM="${STAGE1_PREFIX}/bin/${CTARGET}-nm"
    export RANLIB="${STAGE1_PREFIX}/bin/${CTARGET}-ranlib"
    export STRIP="${STAGE1_PREFIX}/bin/${CTARGET}-strip"
    export OBJCOPY="${STAGE1_PREFIX}/bin/${CTARGET}-objcopy"
    export OBJDUMP="${STAGE1_PREFIX}/bin/${CTARGET}-objdump"

    # Note: Do NOT set PIE flags here manually. GCC's configure will detect PIE requirements
    # and set PICFLAG/LD_PICFLAG appropriately. For Canadian Cross to OHOS, we use
    # --enable-host-pie in configure_gcc() to build PIE-compatible host tools.
    export CFLAGS="${CFLAGS:--g -O2}"
    export CXXFLAGS="${CXXFLAGS:--g -O2}"
    export LDFLAGS="${LDFLAGS:-}"

    # For Canadian Cross build, target tools must be the stage 1 cross-compiler
    # because it can run on the BUILD machine and generate code for TARGET.
    # The newly built compiler (xgcc) cannot run on BUILD machine.
    # Use full paths to ensure we get the right tools.
    export CC_FOR_TARGET="${CC}"
    export CXX_FOR_TARGET="${CXX}"
    export GCC_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-gcc"
    export GXX_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-g++"
    export AR_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-ar"
    export AS_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-as"
    export LD_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-ld"
    export NM_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-nm"
    export RANLIB_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-ranlib"
    export STRIP_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-strip"
    export OBJCOPY_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-objcopy"
    export OBJDUMP_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-objdump"

    # Build tools - must run on the BUILD machine, not the HOST
    # NOTE: We intentionally do NOT export CC_FOR_BUILD/CXX_FOR_BUILD as environment
    # variables. Instead, we pass them on the configure command line in configure_gcc().
    # This ensures the correct build compiler is used without triggering GMP's configure
    # race condition that can occur when CC_FOR_BUILD is exported as an environment
    # variable during parallel configure runs.
    #
    # We set these as shell variables for use in both binutils build and GCC configure.
    # Note: We need to find the native toolchain path to ensure CC_FOR_BUILD can
    # properly link executables. When PATH is modified to include cross tools,
    # the native compiler's collect2 might find the wrong linker.
    local native_bindir="/usr/bin"
    if [[ -x "/usr/bin/${CBUILD}-gcc" ]]; then
        CC_FOR_BUILD="/usr/bin/${CBUILD}-gcc"
        CXX_FOR_BUILD="/usr/bin/${CBUILD}-g++"
    elif [[ -x "/usr/bin/gcc" ]]; then
        CC_FOR_BUILD="/usr/bin/gcc"
        CXX_FOR_BUILD="/usr/bin/g++"
    else
        CC_FOR_BUILD="${CBUILD}-gcc"
        CXX_FOR_BUILD="${CBUILD}-g++"
        if ! command -v "${CC_FOR_BUILD}" >/dev/null 2>&1; then
            CC_FOR_BUILD="gcc"
            CXX_FOR_BUILD="g++"
        fi
    fi
    
    # Set AR_FOR_BUILD, RANLIB_FOR_BUILD etc. for building tools that run on BUILD machine
    # This is critical for build-libiberty which needs native ar, not cross ar
    if [[ -x "/usr/bin/${CBUILD}-ar" ]]; then
        AR_FOR_BUILD="/usr/bin/${CBUILD}-ar"
        RANLIB_FOR_BUILD="/usr/bin/${CBUILD}-ranlib"
    elif [[ -x "/usr/bin/ar" ]]; then
        AR_FOR_BUILD="/usr/bin/ar"
        RANLIB_FOR_BUILD="/usr/bin/ranlib"
    else
        AR_FOR_BUILD="ar"
        RANLIB_FOR_BUILD="ranlib"
    fi
    
    # Add -B flag via CFLAGS_FOR_BUILD to tell the compiler where to find the native 
    # binutils (ld, as, etc.). This is critical for Canadian Cross builds where PATH 
    # is modified to include cross-compiler tools, which could confuse collect2's 
    # linker search. We cannot add -B to CC_FOR_BUILD because env command cannot
    # handle values with spaces properly.
    export CFLAGS_FOR_BUILD="-g -O2 -B${native_bindir}"
    export CXXFLAGS_FOR_BUILD="-g -O2 -B${native_bindir}"
    export LDFLAGS_FOR_BUILD="-B${native_bindir}"

    msg "Canadian Cross environment configured:"
    echo "  PATH includes: ${STAGE1_PREFIX}/bin"
    echo "  CC=${CC}"
    echo "  CC_FOR_BUILD=${CC_FOR_BUILD} (not exported, to avoid GMP configure race)"
    echo "  AR_FOR_BUILD=${AR_FOR_BUILD}"
    echo "  RANLIB_FOR_BUILD=${RANLIB_FOR_BUILD}"
    echo "  CFLAGS_FOR_BUILD=${CFLAGS_FOR_BUILD}"
    echo "  GCC_FOR_TARGET=${GCC_FOR_TARGET}"
    echo "  CFLAGS=${CFLAGS}"
    echo "  LDFLAGS=${LDFLAGS}"
    echo "  CBUILD=${CBUILD}"
    echo "  CHOST=${CHOST}"
    echo "  CTARGET=${CTARGET}"
}

# Setup environment for native OHOS build (stage 3)
setup_native_ohos_env() {
    msg "Setting up native OHOS (stage 3) build environment..."

    # Handle STAGE2_PREFIX=/ to avoid double slashes like //bin/gcc
    local prefix_bin
    if [ "${STAGE2_PREFIX}" = "/" ]; then
        prefix_bin="/bin"
    else
        prefix_bin="${STAGE2_PREFIX}/bin"
    fi

    # Use stage 2 native compiler as the host/target compiler
    # Try unprefixed first, fall back to prefixed
    if [ -x "${prefix_bin}/gcc" ]; then
        export CC="${prefix_bin}/gcc"
        export CXX="${prefix_bin}/g++"
        export AR="${prefix_bin}/ar"
        export AS="${prefix_bin}/as"
        export LD="${prefix_bin}/ld"
        export NM="${prefix_bin}/nm"
        export RANLIB="${prefix_bin}/ranlib"
        export STRIP="${prefix_bin}/strip"
        export OBJCOPY="${prefix_bin}/objcopy"
        export OBJDUMP="${prefix_bin}/objdump"
    else
        export CC="${prefix_bin}/${CTARGET}-gcc"
        export CXX="${prefix_bin}/${CTARGET}-g++"
        export AR="${prefix_bin}/${CTARGET}-ar"
        export AS="${prefix_bin}/${CTARGET}-as"
        export LD="${prefix_bin}/${CTARGET}-ld"
        export NM="${prefix_bin}/${CTARGET}-nm"
        export RANLIB="${prefix_bin}/${CTARGET}-ranlib"
        export STRIP="${prefix_bin}/${CTARGET}-strip"
        export OBJCOPY="${prefix_bin}/${CTARGET}-objcopy"
        export OBJDUMP="${prefix_bin}/${CTARGET}-objdump"
    fi

    # For native build, all tools are the same
    export CC_FOR_TARGET="${CC}"
    export CXX_FOR_TARGET="${CXX}"
    export AR_FOR_TARGET="${AR}"
    export AS_FOR_TARGET="${AS}"
    export LD_FOR_TARGET="${LD}"
    export NM_FOR_TARGET="${NM}"
    export RANLIB_FOR_TARGET="${RANLIB}"
    export STRIP_FOR_TARGET="${STRIP}"
    export OBJCOPY_FOR_TARGET="${OBJCOPY}"
    export OBJDUMP_FOR_TARGET="${OBJDUMP}"

    # Add stage 2 toolchain to PATH (avoid adding / to PATH)
    if [ "${STAGE2_PREFIX}" != "/" ]; then
        export PATH="${prefix_bin}:${PATH}"
    fi

    # For native OHOS builds, we do NOT set --sysroot in CFLAGS
    # The system libraries are already in /lib and /usr/lib
    # Using NDK sysroot would pull in Clang-specific fortify headers that break GCC
    export CFLAGS="${CFLAGS:--O2 -g}"
    export CXXFLAGS="${CXXFLAGS:--O2 -g}"

    msg "Native OHOS environment configured:"
    echo "  CC=${CC}"
    echo "  CFLAGS=${CFLAGS}"
    echo "  CBUILD=${CBUILD}"
    echo "  CHOST=${CHOST}"
    echo "  CTARGET=${CTARGET}"
}

# ============================================================================
# Build Steps
# ============================================================================

prepare_ndk() {
    msg "Preparing NDK sysroot..."

    local ndk_tarball="${SCRIPT_DIR}/ndk-llvm.tar.gz"
    local ndk_extract_tmp="${NDK_DIR}/tmp-extract"

    # Check if sysroot already exists for current target
    if [ -d "${NDK_SYSROOT_DIR}/${CTARGET}" ]; then
        msg "NDK sysroot for ${CTARGET} already exists at ${NDK_SYSROOT_DIR}/${CTARGET}"
        return 0
    fi

    mkdir -p "${NDK_DIR}"

    # Download NDK if not present
    if [ ! -f "${ndk_tarball}" ]; then
        msg "Downloading NDK from ${NDK_URL}..."
        wget -O "${ndk_tarball}" "${NDK_URL}" || \
            error "Failed to download NDK"
    fi

    # Extract ohos-sysroot.tar.gz from NDK package
    msg "Extracting ohos-sysroot.tar.gz from NDK package..."
    local sysroot_tarball="${NDK_DIR}/ohos-sysroot.tar.gz"
    tar -xzf "${ndk_tarball}" -C "${NDK_DIR}" 'ohos-sysroot.tar.gz' || \
        error "Failed to extract ohos-sysroot.tar.gz from NDK package"

    if [ ! -f "${sysroot_tarball}" ]; then
        error "ohos-sysroot.tar.gz not found after extraction"
    fi

    # Extract sysroot to temp directory first (it contains sysroot/ subdirectory)
    msg "Extracting sysroot..."
    mkdir -p "${ndk_extract_tmp}"
    tar -xzf "${sysroot_tarball}" -C "${ndk_extract_tmp}" || \
        error "Failed to extract sysroot"

    # Move contents from sysroot/ subdirectory to NDK_SYSROOT_DIR
    # ohos-sysroot.tar.gz structure: sysroot/{aarch64-linux-ohos,arm-linux-ohos,...}
    msg "Moving sysroot to ${NDK_SYSROOT_DIR}..."
    mkdir -p "${NDK_SYSROOT_DIR}"
    if [ -d "${ndk_extract_tmp}/sysroot" ]; then
        mv "${ndk_extract_tmp}/sysroot"/* "${NDK_SYSROOT_DIR}/" || \
            error "Failed to move sysroot contents"
    else
        error "sysroot directory not found in ohos-sysroot.tar.gz"
    fi

    # Clean up
    rm -rf "${ndk_extract_tmp}"
    rm -f "${sysroot_tarball}"

    msg "NDK sysroot prepared at ${NDK_SYSROOT_DIR}"
}

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

    # Update config.sub/config.guess to latest versions with OHOS support
    # This replaces the need for config.sub patches
    update_config_scripts "${BINUTILS_SOURCE_DIR}"

    msg "Applying binutils patches..."
    cd "${BINUTILS_SOURCE_DIR}"

    for patch in "${SCRIPT_DIR}"/binutils-patches/*.patch; do
        [ -f "${patch}" ] || continue
        # Skip config.sub patches since we use auto-update
        [[ "$(basename "${patch}")" == *config-sub* ]] && continue
        msg "Applying $(basename "${patch}")..."
        patch -p1 -N -i "${patch}" || msg "Patch $(basename "${patch}") already applied or failed"
    done

    cd "${SCRIPT_DIR}"
}

build_binutils() {

    # Check toolchains first (before subshell)
    if is_native_ohos_build && [ -n "${STAGE2_PREFIX}" ]; then
        check_stage2_toolchain
    elif is_canadian_cross; then
        check_stage1_toolchain
    fi

    msg "Configuring binutils for ${CTARGET}..."
    msg "  CBUILD=${CBUILD}, CHOST=${CHOST}, CTARGET=${CTARGET}"
    mkdir -p "${BINUTILS_BUILD_DIR}"

    # Prepare configure arguments (in parent shell)
    local configure_args=(
        "${BINUTILS_SOURCE_DIR}/configure"
        "--prefix=${BINUTILS_INSTALL_PREFIX}"
        "--build=${CBUILD}"
        "--host=${CHOST}"
        "--target=${CTARGET}"
        "--disable-nls"
        "--disable-werror"
        "--disable-multilib"
        "--disable-gprofng"
        "--enable-default-hash-style=gnu"
        "--with-pkgversion=OHOS Binutils ${BINUTILS_VERSION}"
    )

    # For cross-compiler builds (Stage 1), disable installation of unprefixed tools
    if [ "${CHOST}" = "${CBUILD}" ] && [ "${CTARGET}" != "${CBUILD}" ]; then
        configure_args+=("--program-prefix=${CTARGET}-")
    fi

    # Only pass --with-sysroot for cross-compilation, not for native OHOS builds
    # Native OHOS builds use system libraries directly
    if [ -n "${SYSROOT}" ] && ! is_native_ohos_build; then
        configure_args+=("--with-sysroot=${SYSROOT}")
    fi

    # For Canadian Cross builds, disable plugins to avoid LTO issues
    if is_canadian_cross; then
        configure_args+=("--disable-plugins")
    fi

    # Run configure and build in a subshell to avoid polluting parent environment
    # shellcheck disable=SC2030,SC2031
    (
        cd "${BINUTILS_BUILD_DIR}"
        
        # Setup build environment based on build type (inside subshell)
        if is_native_ohos_build && [ -n "${STAGE2_PREFIX}" ]; then
            setup_native_ohos_env
        elif is_canadian_cross; then
            setup_canadian_cross_env
        fi

        "${configure_args[@]}" || exit 1

        # Pass CC_FOR_BUILD explicitly to make for Canadian Cross
        if is_canadian_cross; then
            make -j"${JOBS}" MAKEINFO=true \
                CC_FOR_BUILD="${CC_FOR_BUILD}" \
                CXX_FOR_BUILD="${CXX_FOR_BUILD}" \
                AR_FOR_BUILD="${AR_FOR_BUILD}" \
                RANLIB_FOR_BUILD="${RANLIB_FOR_BUILD}" \
                || exit 1
        else
            make -j"${JOBS}" MAKEINFO=true || exit 1
        fi
        
        make install DESTDIR="${DESTDIR:-}" MAKEINFO=true || exit 1
    ) || error "Binutils build failed"

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
        # For native OHOS builds, apply patches to system headers
        # For cross-compilation, apply to NDK sysroot
        local patch_target
        if is_native_ohos_build; then
            # Native build: patch system headers in /usr/include
            if [ -d "/usr/include/fortify" ]; then
                patch_target="/"
                msg "Applying sysroot patches to system headers..."
            else
                msg "System headers not found at /usr/include/fortify, skipping sysroot patches"
                return 0
            fi
        else
            # Cross-compilation: patch NDK sysroot
            if [ -n "${SYSROOT}" ] && [ -d "${SYSROOT}" ]; then
                patch_target="${SYSROOT}"
                msg "Applying sysroot patches to ${SYSROOT}..."
            else
                msg "SYSROOT not set or doesn't exist, skipping sysroot patches"
                return 0
            fi
        fi

        local current_dir
        current_dir=$(pwd)
        for patch in "${SCRIPT_DIR}"/sysroot-patches/*.patch; do
            [ -f "${patch}" ] || continue
            msg "Applying $(basename "${patch}")..."
            # BusyBox patch doesn't support -d, so cd into the directory instead
            cd "${patch_target}" && patch -p0 -N -i "${patch}" || msg "Patch $(basename "${patch}") already applied or failed"
            cd "${current_dir}"
        done
    fi
}

# Update config.sub and config.guess using local copies from config/ directory
# These files are bundled with the repository and contain OHOS target support
update_config_scripts() {
    local dir="$1"
    local local_config_sub="${SCRIPT_DIR}/config/config.sub"
    local local_config_guess="${SCRIPT_DIR}/config/config.guess"
    
    msg "Updating config.sub and config.guess in ${dir}..."
    
    # Verify local config.sub exists and has OHOS support
    if [ ! -f "${local_config_sub}" ]; then
        error "Local config.sub not found at ${local_config_sub}"
    fi
    
    if ! grep -qE 'linux-ohos' "${local_config_sub}" 2>/dev/null; then
        error "Local config.sub doesn't have OHOS support"
    fi
    
    msg "  Using local config.sub with OHOS support"
    
    # Find all config.sub files and update them if needed
    local updated=0
    local skipped=0
    while IFS= read -r config_file; do
        # Check if this file already has proper OHOS support
        if grep -qE 'linux-ohos' "${config_file}" 2>/dev/null; then
            skipped=$((skipped + 1))
            continue
        fi
        
        # Update config.sub
        cp "${local_config_sub}" "${config_file}"
        chmod +x "${config_file}"
        updated=$((updated + 1))
        
        # Update config.guess if it exists in the same directory
        local config_dir guess_file
        config_dir=$(dirname "${config_file}")
        guess_file="${config_dir}/config.guess"
        if [ -f "${guess_file}" ] && [ -f "${local_config_guess}" ]; then
            cp "${local_config_guess}" "${guess_file}"
            chmod +x "${guess_file}"
        fi
    done < <(find "${dir}" -name "config.sub" -type f 2>/dev/null)
    
    msg "  Updated ${updated} config.sub files, ${skipped} already had OHOS support"
}

# Download GCC prerequisites (GMP, MPFR, MPC, ISL, gettext)
download_prerequisites() {
    msg "Checking GCC prerequisites..."

    cd "${SOURCE_DIR}"

    # Check if prerequisites already downloaded
    local need_download=0
    for dep in gmp mpfr mpc isl gettext; do
        if [ ! -e "${dep}" ]; then
            need_download=1
            break
        fi
    done

    if [ "${need_download}" -eq 0 ]; then
        msg "Prerequisites already downloaded"
        # Still need to apply patches in case they weren't applied
        apply_prerequisite_patches
        cd "${SCRIPT_DIR}"
        return 0
    fi

    msg "Downloading GCC prerequisites..."

    # Use GCC's contrib script to download prerequisites
    if [ -x "./contrib/download_prerequisites" ]; then
        ./contrib/download_prerequisites || error "Failed to download prerequisites"
    else
        error "download_prerequisites script not found in GCC source"
    fi

    # Apply patches for OHOS support to all prerequisites
    apply_prerequisite_patches

    cd "${SCRIPT_DIR}"
}

# Apply patches to all GCC prerequisites for OHOS support
apply_prerequisite_patches() {
    apply_gmp_patches
    apply_mpfr_patches
    apply_mpc_patches
    apply_isl_patches
    apply_gettext_patches
}

# Apply patches to GCC prerequisites using the generic function
apply_gmp_patches() {
    apply_patches_to_dir "GMP" "${SOURCE_DIR}/gmp" "${SCRIPT_DIR}/gmp-patches"
}

apply_mpfr_patches() {
    apply_patches_to_dir "MPFR" "${SOURCE_DIR}/mpfr" "${SCRIPT_DIR}/mpfr-patches"
}

apply_mpc_patches() {
    apply_patches_to_dir "MPC" "${SOURCE_DIR}/mpc" "${SCRIPT_DIR}/mpc-patches"
}

apply_isl_patches() {
    apply_patches_to_dir "ISL" "${SOURCE_DIR}/isl" "${SCRIPT_DIR}/isl-patches"
}

apply_gettext_patches() {
    apply_patches_to_dir "gettext" "${SOURCE_DIR}/gettext" "${SCRIPT_DIR}/gettext-patches"
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

    # Download prerequisites (GMP, MPFR, MPC, ISL, gettext)
    download_prerequisites

    # Update config.sub/config.guess to latest versions with OHOS support
    # This is done before applying patches since upstream config.sub now has OHOS support
    update_config_scripts "${SOURCE_DIR}"

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

    # Note: setup_*_env functions are called inside the subshell below
    # to avoid polluting the parent shell with exported environment variables.
    # But we need to check toolchains first (before subshell).
    if is_native_ohos_build && [ -n "${STAGE2_PREFIX}" ]; then
        check_stage2_toolchain
    elif is_canadian_cross; then
        check_stage1_toolchain
    fi

    msg "Configuring GCC ${GCC_VERSION} for ${CTARGET}..."

    local extra_binutils_flags=""
    local as_path="${BINUTILS_INSTALL_PREFIX}/bin/${CTARGET}-as"
    local ld_path="${BINUTILS_INSTALL_PREFIX}/bin/${CTARGET}-ld"
    [ -x "${as_path}" ] && extra_binutils_flags+=" --with-as=${as_path}"
    [ -x "${ld_path}" ] && extra_binutils_flags+=" --with-ld=${ld_path}"

    # Create build directory
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"
    
    # Determine build type string for display
    local build_type="native"
    if is_native_ohos_build && [ -n "${STAGE2_PREFIX}" ]; then
        build_type="native OHOS bootstrap (stage 3)"
    elif is_canadian_cross; then
        build_type="Canadian Cross (stage 2)"
    elif [ "${CHOST}" != "${CTARGET}" ]; then
        build_type="cross-compiler (stage 1)"
    fi

    msg "Build configuration:"
    echo "  Build type: ${build_type}"
    echo "  CBUILD=${CBUILD}"
    echo "  CHOST=${CHOST}"
    echo "  CTARGET=${CTARGET}"
    echo "  CTARGET_ARCH=${CTARGET_ARCH}"
    echo "  LANGUAGES=${LANGUAGES}"
    echo "  INSTALL_PREFIX=${INSTALL_PREFIX}"
    echo "  SYSROOT=${SYSROOT}"
    if is_canadian_cross; then
        echo "  STAGE1_PREFIX=${STAGE1_PREFIX}"
    fi
    if is_native_ohos_build && [ -n "${STAGE2_PREFIX}" ]; then
        echo "  STAGE2_PREFIX=${STAGE2_PREFIX}"
    fi
    echo "  CROSS_COMPILE=${CROSS_COMPILE}"
    echo ""

    # Configure GCC
    local cross_configure=()
    local zlib_configure="--with-system-zlib"
    
    if [ "${CBUILD}" != "${CHOST}" ] || [ "${CHOST}" != "${CTARGET}" ]; then
        cross_configure+=("--disable-bootstrap")
    fi
    if [ "${CHOST}" != "${CTARGET}" ] && [ -n "${SYSROOT}" ]; then
        cross_configure+=("--with-sysroot=${SYSROOT}")
    fi
    
    # For Canadian Cross builds, use bundled zlib since OHOS sysroot may not have it
    # Also enable host PIE since OHOS defaults to PIE
    # Use --with-build-time-tools to specify stage 1 tools for running on build machine
    local host_pie_configure=""
    local build_time_tools=""
    local isl_configure=""
    local static_libs_configure=""
    if is_canadian_cross; then
        zlib_configure=""
        host_pie_configure="--enable-host-pie"
        build_time_tools="--with-build-time-tools=${STAGE1_PREFIX}/bin"
        # Disable ISL version check - tests won't run in cross environment anyway
        isl_configure="--disable-isl-version-check"
        # Disable static libstdc++/libgcc linking for build tools (ISL tests, etc.)
        # This avoids link failures on aarch64 where static libgcc lacks __eqtf2/__gttf2
        # (128-bit float comparison functions needed by static libstdc++)
        static_libs_configure="--with-static-standard-libraries=no"
        msg "Canadian Cross: Using bundled zlib, enabling host PIE, and using stage 1 build-time tools"
    fi

    # Run configure in a subshell to avoid polluting the parent shell with
    # exported environment variables (CC, CXX, AR, PATH, cache variables, etc.)
    # All environment setup is done inside this subshell.
    # shellcheck disable=SC2030,SC2031
    (
        # ================================================================
        # Setup build environment based on build type (inside subshell)
        # ================================================================
        if is_native_ohos_build && [ -n "${STAGE2_PREFIX}" ]; then
            setup_native_ohos_env
        elif is_canadian_cross; then
            setup_canadian_cross_env
            # For Canadian Cross, add -B/usr/bin to CC_FOR_BUILD so GMP configure
            # can find the native linker (GMP uses $CC_FOR_BUILD directly)
            export CC_FOR_BUILD="${CC_FOR_BUILD} -B/usr/bin"
            export CXX_FOR_BUILD="${CXX_FOR_BUILD} -B/usr/bin"
            export AR_FOR_BUILD="${AR_FOR_BUILD}"
            export RANLIB_FOR_BUILD="${RANLIB_FOR_BUILD}"
        fi

        # Add binutils to PATH
        if [ -d "${BINUTILS_INSTALL_PREFIX}/bin" ]; then
            export PATH="${BINUTILS_INSTALL_PREFIX}/bin:${PATH}"
        fi
        
        # Configure flags for different build scenarios
        if is_canadian_cross; then
            export CFLAGS="${CFLAGS:-} -g0 -O2"
            export CXXFLAGS="${CXXFLAGS:-} -g0 -O2"
            export CFLAGS_FOR_TARGET="${CFLAGS}"
            export CXXFLAGS_FOR_TARGET="${CXXFLAGS}"
            export LDFLAGS_FOR_TARGET="${LDFLAGS:-}"
        elif [ "${CHOST}" != "${CTARGET}" ]; then
            export CFLAGS="${CFLAGS:-} -g0 -O2"
            export CXXFLAGS="${CXXFLAGS:-} -g0 -O2"
            export CFLAGS_FOR_TARGET=" "
            export CXXFLAGS_FOR_TARGET=" "
            export LDFLAGS_FOR_TARGET=" "
        else
            export CFLAGS="${CFLAGS:-} -g0 -O2"
            export CXXFLAGS="${CXXFLAGS:-} -g0 -O2"
            export CFLAGS_FOR_TARGET="${CFLAGS}"
            export CXXFLAGS_FOR_TARGET="${CXXFLAGS}"
            export LDFLAGS_FOR_TARGET="${LDFLAGS:-}"
            export BOOT_CFLAGS="${CFLAGS}"
            export BOOT_LDFLAGS="${LDFLAGS:-}"
        fi

        # Set *_FOR_TARGET from CROSS_COMPILE if specified
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

        # ================================================================
        # Run configure
        # ================================================================
        # shellcheck disable=SC2086  # Intentional word splitting for configure flags
        "${SOURCE_DIR}/configure" \
            --prefix="${INSTALL_PREFIX}" \
            --mandir="${INSTALL_PREFIX}/share/man" \
            --infodir="${INSTALL_PREFIX}/share/info" \
            --build="${CBUILD}" \
            --host="${CHOST}" \
            --target="${CTARGET}" \
            --with-pkgversion="OHOS GCC ${GCC_VERSION}" \
            --with-bugurl="https://github.com/sanchuanhehe/ohos-gcc" \
            ${zlib_configure} \
            ${host_pie_configure} \
            ${build_time_tools} \
            ${isl_configure} \
            ${static_libs_configure} \
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
            ${EXTRA_CONFIGURE_FLAGS:-}
    ) || error "Configuration failed"
}

build_gcc() {
    msg "Building GCC..."
    cd "${BUILD_DIR}"
    
    # For Canadian Cross builds, we need to explicitly pass GCC_FOR_TARGET
    # pointing to the stage 1 cross-compiler, because the newly built xgcc
    # is an OHOS binary that cannot run on the Linux build machine.
    # We also need to ensure stage 1 tools are in PATH for sub-configures.
    # Use full path to avoid picking up wrong gcc from install prefix.
    if is_canadian_cross; then
        # shellcheck disable=SC2031  # PATH usage here is intentional and not related to subshell modifications
        PATH="${STAGE1_PREFIX}/bin:${PATH}" make -j"${JOBS}" \
            GCC_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-gcc" \
            || error "Build failed"
    else
        make -j"${JOBS}" || error "Build failed"
    fi
}

install_gcc() {
    msg "Installing GCC to ${INSTALL_PREFIX}..."
    cd "${BUILD_DIR}"
    
    # For Canadian Cross builds, pass GCC_FOR_TARGET to avoid trying to run
    # the newly built OHOS binaries on the Linux build machine.
    # Also ensure stage 1 tools are in PATH.
    # Use full path to avoid picking up wrong gcc from install prefix.
    if is_canadian_cross; then
        # shellcheck disable=SC2031  # PATH usage here is intentional and not related to subshell modifications
        PATH="${STAGE1_PREFIX}/bin:${PATH}" make install DESTDIR="${DESTDIR:-}" \
            GCC_FOR_TARGET="${STAGE1_PREFIX}/bin/${CTARGET}-gcc" \
            || error "Installation failed"
    else
        make install DESTDIR="${DESTDIR:-}" || error "Installation failed"
    fi
    
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
    prepare_ndk         Download and setup NDK sysroot only
    prepare             Download NDK/sources and apply patches for binutils and GCC
    download_prereqs    Download GCC prerequisites (GMP, MPFR, MPC, ISL, gettext)
    binutils            Build and install binutils only
    configure           Ensure binutils exist and configure GCC
    build               Build GCC
    install             Install GCC
    all                 Run full pipeline (NDK + binutils + GCC)
    clean               Clean build directories

Options:
  --target=TARGET           Set target triplet (default: aarch64-linux-ohos)
  --host=HOST               Set host triplet (default: auto-detected)
  --build=BUILD             Set build triplet (default: auto-detected)
  --prefix=PREFIX           Set installation prefix (default: ./install)
  --sysroot=SYSROOT         Set sysroot path for cross-compilation
                            (default: ndk/sysroot/CTARGET)
  --stage1=PATH             Stage 1 cross-compiler prefix (for stage 2 builds)
  --stage2=PATH             Stage 2 native compiler prefix (for stage 3 builds)
  --jobs=N                  Number of parallel jobs (default: $(nproc))
  --enable-languages=LIST   Comma-separated language list (default: c,c++)
  --help                    Show this help message

Environment Variables:
  CTARGET                   Target triplet
  CHOST                     Host triplet
  CBUILD                    Build triplet
  INSTALL_PREFIX            Installation prefix
  STAGE1_PREFIX             Stage 1 cross-compiler prefix (for stage 2)
  STAGE2_PREFIX             Stage 2 native compiler prefix (for stage 3)
  BINUTILS_VERSION          Binutils version (default: ${BINUTILS_VERSION})
  BINUTILS_INSTALL_PREFIX   Binutils installation prefix (default: same as INSTALL_PREFIX)
  SYSROOT                   Sysroot path (default: ndk/sysroot/CTARGET)
  NDK_URL                   NDK download URL
  JOBS                      Number of parallel jobs
  CROSS_COMPILE             Cross prefix override (default: target- when cross compiling)
  LANG_*                    Enable/disable specific languages (yes/no)

Build Types:
  Stage 1 (Cross-compiler):
    Builds on host (e.g., x86_64-linux-gnu) to produce a cross-compiler
    that runs on host and targets OHOS.
    CBUILD=CHOST=x86_64-linux-gnu, CTARGET=x86_64-linux-ohos

  Stage 2 (Canadian Cross / Native compiler):
    Uses stage 1 cross-compiler to build a native OHOS compiler.
    The resulting compiler runs on OHOS and produces OHOS binaries.
    CBUILD=x86_64-linux-gnu, CHOST=CTARGET=x86_64-linux-ohos
    Requires --stage1 pointing to stage 1 installation.

  Stage 3 (Native bootstrap):
    Runs on OHOS using stage 2 compiler to rebuild itself.
    Full native build: CBUILD=CHOST=CTARGET=x86_64-linux-ohos
    Requires --stage2 pointing to stage 2 installation.

Examples:
  # Stage 1: Build cross-compiler for x86_64 OHOS
  $0 --target=x86_64-linux-ohos --prefix=/opt/ohos-gcc-stage1

  # Stage 2: Build native OHOS compiler (Canadian Cross)
  $0 --build=x86_64-linux-gnu --host=x86_64-linux-ohos --target=x86_64-linux-ohos --stage1=/opt/ohos-gcc-stage1 --prefix=/opt/ohos-gcc-stage2

  # Stage 3: Native bootstrap on OHOS (run inside OHOS)
  $0 --build=x86_64-linux-ohos --host=x86_64-linux-ohos --target=x86_64-linux-ohos --stage2=/opt/ohos-gcc-stage2 --prefix=/opt/ohos-gcc

  # Build for AArch64 OHOS
  $0 --target=aarch64-linux-ohos --prefix=/opt/ohos-gcc

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
        --stage1=*)
            STAGE1_PREFIX="${1#*=}"
            ;;
        --stage2=*)
            STAGE2_PREFIX="${1#*=}"
            ;;
        --jobs=*)
            JOBS="${1#*=}"
            ;;
        --enable-languages=*)
            LANGUAGES="${1#*=}"
            ;;
        prepare_ndk|prepare|binutils|configure|build|install|all|clean|prepare_binutils|download_prereqs)
            COMMAND="$1"
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
    shift
done

# Normalize all path arguments to absolute form using normalize_path()
# This allows users to specify relative paths like ./install

# Paths that may not exist yet (use normalize_path without must_exist)
INSTALL_PREFIX=$(normalize_path "${INSTALL_PREFIX}")

# BINUTILS_INSTALL_PREFIX inherits from INSTALL_PREFIX if not set
BINUTILS_INSTALL_PREFIX="${BINUTILS_INSTALL_PREFIX:-${INSTALL_PREFIX}}"
if [ "${BINUTILS_INSTALL_PREFIX}" != "${INSTALL_PREFIX}" ]; then
    BINUTILS_INSTALL_PREFIX=$(normalize_path "${BINUTILS_INSTALL_PREFIX}")
fi

# Paths that must exist (stage prefixes, sysroot)
if [ -n "${STAGE1_PREFIX}" ]; then
    STAGE1_PREFIX=$(normalize_path "${STAGE1_PREFIX}" true) || \
        error "Failed to resolve stage1 path: ${STAGE1_PREFIX}"
fi

if [ -n "${STAGE2_PREFIX}" ]; then
    STAGE2_PREFIX=$(normalize_path "${STAGE2_PREFIX}" true) || \
        error "Failed to resolve stage2 path: ${STAGE2_PREFIX}"
fi

if [ -n "${SYSROOT}" ]; then
    SYSROOT=$(normalize_path "${SYSROOT}" true) || \
        error "Failed to resolve sysroot path: ${SYSROOT}"
fi

# Resolve defaults that depend on parsed values
CHOST="${CHOST:-${CBUILD}}"

# Setup target-specific configuration AFTER parsing command line arguments
# This ensures --target is properly respected
setup_target_config

# Determine cross-compilation context after parsing options
if [ -z "${CROSS_COMPILE:-}" ]; then
    if [ "${CHOST}" != "${CTARGET}" ]; then
        CROSS_COMPILE="${CTARGET}-"
    else
        CROSS_COMPILE=""
    fi
fi
export CROSS_COMPILE

# shellcheck disable=SC2034  # Reserved for future use
IS_NATIVE_BUILD=0
if [ "${CHOST}" = "${CTARGET}" ]; then
    # shellcheck disable=SC2034
    IS_NATIVE_BUILD=1
fi

# Set default SYSROOT to NDK sysroot if not specified
if [ -z "${SYSROOT}" ]; then
    SYSROOT="${NDK_SYSROOT_DIR}/${CTARGET}"
    msg "Using default sysroot: ${SYSROOT}"
fi

# Execute command
case "${COMMAND}" in
    prepare_ndk)
        prepare_ndk
        apply_sysroot_patches
        ;;
    prepare)
        prepare_ndk
        prepare_binutils
        apply_sysroot_patches
        prepare_gcc
        ;;
    prepare_binutils)
        prepare_binutils
        ;;
    download_prereqs)
        # Ensure GCC source exists before downloading prerequisites
        if [ ! -d "${SOURCE_DIR}" ]; then
            error "GCC source directory not found: ${SOURCE_DIR}
Please run 'prepare' or download GCC source first."
        fi
        download_prerequisites
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
        prepare_ndk
        prepare_binutils
        apply_sysroot_patches
        prepare_gcc
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