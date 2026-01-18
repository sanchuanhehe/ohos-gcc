# GCC for OpenHarmony (OHOS) 详细构建指南

本文档提供 GCC OHOS 工具链的详细构建说明，包括三阶段构建流程、高级配置选项和故障排除。

> 💡 **快速入门**: 如需快速上手，请参阅 [README.md](README.md)。

## 目录

- [概述](#概述)
- [系统要求](#系统要求)
- [三阶段构建流程](#三阶段构建流程)
- [构建选项详解](#构建选项详解)
- [高级用法](#高级用法)
- [架构特定配置](#架构特定配置)
- [补丁说明](#补丁说明)
- [编译示例](#编译示例)
- [故障排除](#故障排除)
- [参考资料](#参考资料)

## 概述

本项目基于 Alpine Linux 的 GCC APKBUILD，为 OpenHarmony (OHOS) 目标提供完整的 GCC 交叉编译工具链。

### 特性

| 特性 | 描述 |
|------|------|
| 🏗️ 多架构支持 | AArch64, ARM, x86/x86_64, RISC-V, MIPS |
| 📦 基于 GCC 15.2.0 | 最新稳定版本 |
| 📚 使用 musl libc | 轻量级 C 标准库 |
| 🔧 OHOS 特定补丁 | 42 个专用补丁 |
| 🔒 安全特性 | 默认启用 PIE, SSP, FORTIFY_SOURCE |
| 🔄 完整构建支持 | 支持交叉编译、Canadian Cross、原生自举 |

## 系统要求

### 硬件要求

| 资源 | 最低要求 | 推荐配置 |
|------|----------|----------|
| CPU | 4 核 | 8+ 核 |
| 内存 | 8 GB | 16+ GB |
| 磁盘 | 20 GB | 50+ GB |
| 网络 | 用于下载源码 | - |

### 构建依赖

**Ubuntu/Debian:**

```bash
sudo apt-get install -y \
    build-essential \
    bison \
    flex \
    texinfo \
    gawk \
    zip \
    unzip \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    zlib1g-dev \
    wget \
    git \
    curl \
    xz-utils \
    python3
```

**Fedora/RHEL:**

```bash
sudo dnf install -y \
    gcc \
    gcc-c++ \
    bison \
    flex \
    texinfo \
    gawk \
    zip \
    unzip \
    gmp-devel \
    mpfr-devel \
    libmpc-devel \
    zlib-devel \
    wget \
    git \
    curl \
    xz \
    python3
```

**Arch Linux:**

```bash
sudo pacman -S base-devel bison flex texinfo gawk zip unzip gmp mpfr libmpc wget git
```

## 三阶段构建流程

### Stage 1: 交叉编译器（在 Linux 上运行，生成 OHOS 代码）

```bash
git clone https://github.com/sanchuanhehe/ohos-gcc.git
cd ohos-gcc
```

**构建 AArch64 目标（默认）:**

```bash
./build.sh --target=aarch64-linux-ohos --prefix=/opt/ohos-gcc
```

**构建 ARM 目标:**

```bash
./build.sh --target=arm-linux-ohos --prefix=/opt/ohos-gcc-arm
```

**构建 x86_64 目标:**

```bash
./build.sh --target=x86_64-linux-ohos --prefix=/opt/ohos-gcc-x86_64
```

**构建 RISC-V 目标:**

```bash
./build.sh --target=riscv64-linux-ohos --prefix=/opt/ohos-gcc-riscv64
```

### Stage 2: Canadian Cross（生成在 OHOS 上运行的原生编译器）

```bash
# 需要先完成 Stage 1
./build.sh \
    --build=x86_64-linux-gnu \
    --host=aarch64-linux-ohos \
    --target=aarch64-linux-ohos \
    --stage1=/opt/ohos-gcc \
    --prefix=/opt/ohos-gcc-native \
    all
```

### Stage 3: 原生自举（在 OHOS 设备上验证工具链）

```bash
# 在 OHOS 设备上执行
./build.sh \
    --build=aarch64-linux-ohos \
    --host=aarch64-linux-ohos \
    --target=aarch64-linux-ohos \
    --stage2=/opt/ohos-gcc-native \
    --prefix=/opt/ohos-gcc-bootstrap \
    all
```

### 使用编译好的工具链

```bash
export PATH=/opt/ohos-gcc/bin:$PATH
aarch64-linux-ohos-gcc --version
```

## 构建选项详解

### 指定 Sysroot（交叉编译）

如果你有 OHOS 的 sysroot，可以这样构建：

```bash
./build.sh \
    --target=aarch64-linux-ohos \
    --prefix=/opt/ohos-gcc \
    --sysroot=/path/to/ohos-sysroot
```

> **注意**: 如果不指定 sysroot，脚本会自动从 OpenHarmony CI 下载 NDK sysroot。

### 可重定位工具链

构建可分发的工具链（使用相对 sysroot 路径）：

```bash
./build.sh \
    --target=aarch64-linux-ohos \
    --prefix=/opt/ohos-gcc \
    --relocatable-sysroot
```

    --sysroot=/path/to/ohos-sysroot

```

### 自定义语言支持

默认只启用 C 和 C++。如果需要其他语言：

```bash
# 启用 C, C++, Fortran
./build.sh --enable-languages=c,c++,fortran

# 或者使用环境变量
export LANG_FORTRAN=yes
export LANG_GO=yes
./build.sh
```

### 并行构建

```bash
# 使用 8 个并行任务
./build.sh --jobs=8

# 或设置环境变量
export JOBS=8
./build.sh
```

### 分步构建

```bash
# 仅准备源码（应用补丁）
./build.sh prepare

# 仅配置
./build.sh configure

# 仅构建
./build.sh build

# 仅安装
./build.sh install

# 清理构建目录
./build.sh clean
```

## 构建选项

### 命令行参数

| 参数 | 说明 | 默认值 |
|------|------|--------|
| `--target=TARGET` | 目标三元组 | `aarch64-linux-ohos` |
| `--host=HOST` | 主机三元组（编译器运行平台） | 自动检测 |
| `--build=BUILD` | 构建机器三元组 | 自动检测 |
| `--prefix=PREFIX` | 安装前缀 | `./install` |
| `--sysroot=SYSROOT` | 交叉编译的 sysroot 路径 | `ndk/sysroot` |
| `--stage1=PATH` | Stage 1 安装路径 | - |
| `--stage2=PATH` | Stage 2 安装路径 | - |
| `--jobs=N` | 并行任务数 | `$(nproc)` |
| `--enable-languages=LIST` | 语言列表，逗号分隔 | `c,c++` |
| `--relocatable-sysroot` | 使用相对 sysroot 路径 | `no` |
| `--help` | 显示帮助信息 | - |

### 构建命令

| 命令 | 说明 |
|------|------|
| `prepare_ndk` | 下载并设置 NDK sysroot |
| `prepare` | 准备所有源码（应用补丁） |
| `binutils` | 仅构建 binutils |
| `configure` | 仅配置 GCC |
| `build` | 仅编译 GCC |
| `install` | 仅安装 GCC |
| `all` | 完整构建流程（默认） |
| `clean` | 清理构建目录 |

### 环境变量

**目标配置:**

```bash
export CTARGET=aarch64-linux-ohos    # 目标三元组
export CHOST=aarch64-linux-ohos      # 主机三元组（Stage 2/3）
export CBUILD=x86_64-linux-gnu       # 构建机器三元组
export INSTALL_PREFIX=/opt/ohos-gcc  # 安装路径
export SYSROOT=/path/to/sysroot      # Sysroot 路径
export STAGE1_PREFIX=./install       # Stage 1 安装路径
export STAGE2_PREFIX=./install-stage2 # Stage 2 安装路径
```

**语言支持:**

```bash
export LANG_CXX=yes         # C++ 支持（默认: yes）
export LANG_FORTRAN=no      # Fortran 支持（默认: no）
export LANG_GO=no           # Go 支持（默认: no）
export LANG_D=no            # D 支持（默认: no）
export LANG_OBJC=no         # Objective-C 支持（默认: no）
export LANG_ADA=no          # Ada 支持（默认: no）
export LANG_JIT=no          # JIT 支持（默认: no）
```

**库特性:**

```bash
export LIBGOMP=no           # OpenMP 支持（默认: no，交叉编译禁用）
export LIBATOMIC=no         # 原子操作库（默认: no，交叉编译禁用）
export LIBITM=no            # 事务内存库（默认: no）
export LIBQUADMATH=no       # 128位浮点数库（默认: no）
```

**构建控制:**

```bash
export JOBS=8               # 并行任务数
export NDK_URL="..."        # NDK 下载地址
export RELOCATABLE_SYSROOT=yes  # 可重定位 sysroot
```

## 高级用法

### 分步构建

```bash
# 1. 仅准备源码（下载 + 应用补丁）
./build.sh prepare_ndk
./build.sh prepare

# 2. 仅构建 binutils
./build.sh binutils

# 3. 仅配置 GCC
./build.sh configure

# 4. 仅编译 GCC
./build.sh build

# 5. 仅安装
./build.sh install

# 清理构建目录重新开始
./build.sh clean
```

### 并行构建优化

```bash
# 使用所有 CPU 核心
./build.sh --jobs=$(nproc)

# 限制内存使用（每任务约 2GB）
./build.sh --jobs=$(($(free -g | awk '/^Mem:/{print $2}') / 2))
```

### 交互式构建示例

```bash
# 使用交互式脚本选择架构
./build-examples.sh
```

## 架构特定配置

| 架构 | 目标三元组 | 架构选项 | 特殊说明 |
|------|-----------|---------|----------|
| AArch64 | `aarch64-linux-ohos` | `--with-arch=armv8-a --with-abi=lp64` | 推荐，主流设备 |
| ARM (软浮点) | `arm-linux-ohos` | `--with-arch=armv5te --with-float=soft` | 兼容性好 |
| ARM (硬浮点) | `armhf-linux-ohos` | `--with-arch=armv7-a --with-fpu=vfpv3-d16 --with-float=hard` | 性能更好 |
| x86_64 | `x86_64-linux-ohos` | - | 支持 libsanitizer |
| x86 (i686) | `i686-linux-ohos` | `--with-arch=i486 --with-tune=generic` | 32位兼容 |
| RISC-V 64 | `riscv64-linux-ohos` | `--with-arch=rv64gc --with-abi=lp64d` | 新兴架构 |
| MIPS64 (小端) | `mips64el-linux-ohos` | `--with-arch=mips3 --with-abi=64` | 软浮点 |
| MIPS64 (大端) | `mips64-linux-ohos` | `--with-arch=mips3 --with-abi=64` | 软浮点 |
| MIPS (小端) | `mipsel-linux-ohos` | `--with-arch=mips32 --with-abi=32` | 32位软浮点 |
| MIPS (大端) | `mips-linux-ohos` | `--with-arch=mips32 --with-abi=32` | 32位软浮点 |

## 补丁说明

项目包含 **42 个 GCC 补丁** 和 **4 个 Binutils 补丁**，主要分为以下类别：

### OHOS 目标支持补丁

| 补丁 | 说明 |
|------|------|
| `0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch` | 核心 OHOS 目标支持 |

### 安全加固补丁

| 补丁 | 说明 |
|------|------|
| `0002-gcc-poison-system-directories.patch` | 防止使用系统目录 |
| `0003-specs-turn-on-Wl-z-now-by-default.patch` | 默认启用 RELRO |
| `0004-Turn-on-D_FORTIFY_SOURCE-2-by-default.patch` | 默认启用 FORTIFY_SOURCE |
| `0006-Enable-Wformat-and-Wformat-security-by-default.patch` | 启用格式字符串安全警告 |
| `0007-Enable-Wtrampolines-by-default.patch` | 启用跳板代码警告 |
| `0008-gcc-disable-SSP-on-ffreestanding-nostdlib.patch` | 独立环境禁用 SSP |
| `0009-gcc-params-set-default-ssp-buffer-size-to-4.patch` | SSP 缓冲区大小 |

### musl libc 兼容性补丁

| 补丁 | 说明 |
|------|------|
| `0011-Don-t-declare-asprintf-if-defined-as-a-macro.patch` | asprintf 兼容 |
| `0013-libgcc_s.patch` | libgcc_s 链接修复 |
| `0018-Alpine-musl-package-provides-libssp_nonshared.a.patch` | SSP 库兼容 |
| `0026-ada-libgnarl-remove-use-of-glibc-specific-pthread_rw.patch` | Ada pthread 兼容 |
| `0031-libstdc-do-not-throw-exceptions-for-non-C-locales.patch` | locale 异常处理 |
| `0034-libgnat-time_t-is-always-64-bit-on-musl-libc.patch` | time_t 64位支持 |
| `0035-libphobos-do-not-use-LFS64-symbols.patch` | LFS64 符号兼容 |

### 架构特定补丁

| 补丁 | 说明 |
|------|------|
| `0020-aarch64-disable-multilib-support.patch` | AArch64 禁用 multilib |
| `0021-s390x-disable-multilib-support.patch` | s390x 禁用 multilib |
| `0023-x86_64-disable-multilib-support.patch` | x86_64 禁用 multilib |
| `0024-riscv-disable-multilib-support.patch` | RISC-V 禁用 multilib |
| `0037-loongarch-disable-multilib-support.patch` | LoongArch 禁用 multilib |

### Sysroot 补丁 (`sysroot-patches/`)

| 补丁 | 说明 |
|------|------|
| `fortify-gcc-compat.patch` | FORTIFY 与 GCC 兼容 |
| `string-gcc.patch` | string.h GCC 兼容 |
| `sys-sysinfo.patch` | sysinfo.h 修复 |

## 编译示例

### Hello World (C)

```bash
# 编写源码
cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello, OpenHarmony!\n");
    return 0;
}
EOF

# 交叉编译（使用 sysroot）
aarch64-linux-ohos-gcc \
    --sysroot=/path/to/ohos-sysroot \
    -o hello \
    hello.c

# 静态链接（无需 sysroot）
aarch64-linux-ohos-gcc \
    -static \
    -o hello-static \
    hello.c
```

### Hello World (C++)

```bash
cat > hello.cpp << 'EOF'
#include <iostream>
#include <string>

int main() {
    std::string msg = "Hello, OpenHarmony C++!";
    std::cout << msg << std::endl;
    return 0;
}
EOF

aarch64-linux-ohos-g++ \
    --sysroot=/path/to/ohos-sysroot \
    -o hello-cpp \
    hello.cpp
```

### 多文件项目

```bash
# 编译对象文件
aarch64-linux-ohos-gcc -c main.c -o main.o
aarch64-linux-ohos-gcc -c utils.c -o utils.o

# 链接
aarch64-linux-ohos-gcc main.o utils.o -o myapp
```

### 使用 Make 构建

```makefile
# Makefile
CC = aarch64-linux-ohos-gcc
CXX = aarch64-linux-ohos-g++
SYSROOT = /path/to/sysroot
CFLAGS = --sysroot=$(SYSROOT) -O2 -Wall
CXXFLAGS = $(CFLAGS)

all: myapp

myapp: main.o utils.o
 $(CC) $(CFLAGS) -o $@ $^

%.o: %.c
 $(CC) $(CFLAGS) -c -o $@ $<

clean:
 rm -f *.o myapp
```

## 故障排除

### 问题：configure 失败

**症状:** `configure: error: ...` 或 `checking for ... no`

**解决方案:**

```bash
# 确保已安装所有依赖
sudo apt-get install -y build-essential bison flex texinfo gawk zip \
    libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev

# 检查 config.log 获取详细信息
cat build-ohos/config.log | grep -i "error\|failed"

# 清理并重试
./build.sh clean
./build.sh all
```

### 问题：Stage 2 构建失败

**症状:** `cannot find stage 1 compiler` 或链接错误

**解决方案:**

```bash
# 验证 Stage 1 工具链
ls -la /opt/ohos-gcc-stage1/bin/
/opt/ohos-gcc-stage1/bin/aarch64-linux-ohos-gcc --version

# 确保路径正确
./build.sh \
    --stage1=/opt/ohos-gcc-stage1 \  # 绝对路径
    --host=aarch64-linux-ohos \
    --target=aarch64-linux-ohos \
    all
```

### 问题：链接失败

**症状:** `undefined reference to ...` 或 `cannot find -lc`

**解决方案:**

```bash
# 检查 sysroot 是否完整
ls /path/to/sysroot/usr/lib/
ls /path/to/sysroot/usr/include/

# 使用正确的 sysroot
./build.sh --sysroot=/correct/path/to/sysroot all

# 或使用静态链接测试
aarch64-linux-ohos-gcc -static -o test test.c
```

### 问题：找不到头文件

**症状:** `fatal error: xxx.h: No such file or directory`

**解决方案:**

```bash
# 检查头文件位置
find /path/to/sysroot -name "stdio.h"

# 应用 sysroot 补丁
cd /path/to/sysroot
patch -p0 < /path/to/ohos-gcc/sysroot-patches/fortify-gcc-compat.patch

# 显式指定 include 路径
aarch64-linux-ohos-gcc -I/path/to/sysroot/usr/include ...
```

### 问题：构建时间过长

**解决方案:**

```bash
# 增加并行任务数
./build.sh --jobs=$(nproc)

# 仅构建需要的语言
./build.sh --enable-languages=c,c++

# 使用 ccache 加速重编译
export PATH="/usr/lib/ccache:$PATH"
./build.sh all
```

### 问题：磁盘空间不足

**解决方案:**

```bash
# 检查磁盘使用
df -h .

# 清理中间文件
./build.sh clean

# 删除下载缓存
rm -rf downloads/

# 构建后清理
rm -rf build-ohos build-binutils
```

### 问题：内存不足 (OOM)

**解决方案:**

```bash
# 减少并行任务数
./build.sh --jobs=2

# 添加 swap 空间
sudo fallocate -l 8G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
```

## 目录结构

```
ohos-gcc/
├── 📄 build.sh                 # 主构建脚本
├── 📄 build-tools.sh           # 辅助工具构建脚本
├── 📄 build-examples.sh        # 交互式示例
├── 📄 test-toolchain.sh        # 工具链测试
├── 📄 BUILD_OHOS.md            # 本文档
├── 📄 README.md                # 项目说明
├── 📄 CONTRIBUTING.md          # 贡献指南
│
├── 📁 gcc-patches/             # GCC 补丁 (42个)
├── 📁 binutils-patches/        # Binutils 补丁 (4个)
├── 📁 sysroot-patches/         # Sysroot 补丁 (3个)
├── 📁 config/                  # 配置文件
│
├── 📁 gcc-15.2.0/              # GCC 源码
├── 📁 binutils-2.43/           # Binutils 源码
├── 📁 ndk/                     # NDK sysroot
│   └── sysroot/
│       └── <target>/
│           ├── usr/include/    # 头文件
│           └── usr/lib/        # 库文件
│
├── 📁 build-ohos/              # GCC 构建目录
├── 📁 build-binutils/          # Binutils 构建目录
├── 📁 build-tools/             # 辅助工具构建目录
├── 📁 downloads/               # 下载缓存
│
├── 📁 install/                 # Stage 1 安装目录
│   ├── bin/                    # 编译器和工具
│   ├── lib/gcc/<target>/       # GCC 库
│   ├── libexec/gcc/<target>/   # GCC 内部工具
│   └── <target>/               # 目标特定文件
│       ├── bin/                # 目标工具
│       ├── include/            # 目标头文件
│       └── lib/                # 目标库
│
└── 📁 install-tools/           # 辅助工具安装目录
    └── bin/                    # make, bash, gawk, patch
```

## 参考资料

### 官方文档

- [GCC 官方文档](https://gcc.gnu.org/onlinedocs/)
- [GCC 安装指南](https://gcc.gnu.org/install/)
- [GNU Binutils 文档](https://sourceware.org/binutils/docs/)
- [OpenHarmony 官网](https://www.openharmony.cn/)

### 交叉编译资源

- [Cross Linux From Scratch](https://clfs.org/)
- [Canadian Cross 编译](https://clfs.org/view/clfs-3.0.0-sysvinit/mips64-64/cross-tools/cross-gcc.html)
- [GCC Cross-Compiler HOWTO](https://wiki.osdev.org/GCC_Cross-Compiler)

### musl libc

- [musl libc 官网](https://musl.libc.org/)
- [musl libc FAQ](https://wiki.musl-libc.org/faq.html)
- [musl vs glibc 差异](https://wiki.musl-libc.org/functional-differences-from-glibc.html)

### Alpine Linux 参考

- [Alpine Linux GCC APKBUILD](https://git.alpinelinux.org/aports/tree/main/gcc)
- [Alpine Linux 交叉编译](https://wiki.alpinelinux.org/wiki/Cross_compiling)

## 贡献

欢迎提交 Issue 和 Pull Request！

请参阅 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详细的贡献指南。

## 许可证

- **GCC**: GPL-3.0-or-later with GCC Runtime Library Exception
- **Binutils**: GPL-3.0-or-later
- **本项目脚本**: GPL-3.0

## 致谢

- [Alpine Linux](https://alpinelinux.org/) - 构建脚本和补丁参考
- [GCC Project](https://gcc.gnu.org/) - GNU 编译器集合
- [OpenHarmony](https://www.openharmony.cn/) - 目标操作系统
- [musl libc](https://musl.libc.org/) - 轻量级 C 标准库
- [docker-mini-openharmony](https://github.com/hqzing/docker-mini-openharmony) - Docker 开发环境

---

<p align="center">
  <b>有问题?</b> 请 <a href="https://github.com/sanchuanhehe/ohos-gcc/issues">提交 Issue</a>
</p>
