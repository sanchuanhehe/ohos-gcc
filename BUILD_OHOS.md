# GCC for OpenHarmony (OHOS) 构建指南

这个项目基于 Alpine Linux 的 GCC APKBUILD，为 OpenHarmony (OHOS) 目标提供 GCC 交叉编译工具链。

## 特性

- 支持多架构：AArch64, ARM, x86/x86_64, RISC-V, MIPS
- 基于 GCC 15.2.0
- 使用 musl libc
- 包含 OHOS 特定补丁
- 默认启用安全特性（PIE, SSP）
- 支持交叉编译和本地编译

## 系统要求

### 构建依赖

```bash
# Ubuntu/Debian
sudo apt-get install -y \
    build-essential \
    bison \
    flex \
    texinfo \
    gawk \
    zip \
    libgmp-dev \
    libmpfr-dev \
    libmpc-dev \
    zlib1g-dev \
    wget

# Fedora/RHEL
sudo dnf install -y \
    gcc \
    gcc-c++ \
    bison \
    flex \
    texinfo \
    gawk \
    zip \
    gmp-devel \
    mpfr-devel \
    libmpc-devel \
    zlib-devel \
    wget
```

## 快速开始

### 1. 克隆仓库

```bash
git clone <your-repo-url> ohos-gcc
cd ohos-gcc
```

### 2. 构建 GCC

#### 构建 AArch64 目标（默认）

```bash
./build.sh --target=aarch64-linux-ohos --prefix=/opt/ohos-gcc
```

#### 构建 ARM 目标

```bash
./build.sh --target=arm-linux-ohos --prefix=/opt/ohos-gcc-arm
```

#### 构建 x86_64 目标

```bash
./build.sh --target=x86_64-linux-ohos --prefix=/opt/ohos-gcc-x86_64
```

#### 构建 RISC-V 目标

```bash
./build.sh --target=riscv64-linux-ohos --prefix=/opt/ohos-gcc-riscv64
```

### 3. 使用编译好的工具链

```bash
export PATH=/opt/ohos-gcc/bin:$PATH
aarch64-linux-ohos-gcc --version
```

## 高级用法

### 指定 Sysroot（交叉编译）

如果你有 OHOS 的 sysroot，可以这样构建：

```bash
./build.sh \
    --target=aarch64-linux-ohos \
    --prefix=/opt/ohos-gcc \
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

```
--target=TARGET           设置目标三元组（默认: aarch64-linux-ohos）
--prefix=PREFIX           设置安装前缀（默认: ./install）
--sysroot=SYSROOT         设置交叉编译的 sysroot 路径
--jobs=N                  并行任务数（默认: CPU 核心数）
--enable-languages=LIST   语言列表，逗号分隔（默认: c,c++）
--help                    显示帮助信息
```

### 环境变量

```bash
# 目标配置
export CTARGET=aarch64-linux-ohos
export INSTALL_PREFIX=/opt/ohos-gcc
export SYSROOT=/path/to/sysroot

# 语言支持
export LANG_CXX=yes         # C++ 支持（默认: yes）
export LANG_FORTRAN=yes     # Fortran 支持（默认: no）
export LANG_GO=yes          # Go 支持（默认: no）
export LANG_D=yes           # D 支持（默认: no）
export LANG_OBJC=yes        # Objective-C 支持（默认: no）
export LANG_ADA=yes         # Ada 支持（默认: no）
export LANG_JIT=yes         # JIT 支持（默认: no）

# 库特性
export LIBGOMP=yes          # OpenMP 支持（默认: yes）
export LIBATOMIC=yes        # 原子操作库（默认: yes）
export LIBITM=yes           # 事务内存库（默认: yes）
export LIBQUADMATH=yes      # 128位浮点数库（默认: no）

# 构建并行度
export JOBS=8
```

## 支持的目标架构

| 架构 | 目标三元组 | 说明 |
|------|-----------|------|
| AArch64 | `aarch64-linux-ohos` | ARM 64位 |
| ARM (soft float) | `arm-linux-ohos` | ARM 32位软浮点 |
| ARM (hard float) | `armhf-linux-ohos` | ARM 32位硬浮点 |
| x86_64 | `x86_64-linux-ohos` | Intel/AMD 64位 |
| x86 | `i686-linux-ohos` | Intel/AMD 32位 |
| RISC-V 64 | `riscv64-linux-ohos` | RISC-V 64位 |
| MIPS 64 (LE) | `mips64el-linux-ohos` | MIPS 64位小端 |
| MIPS 64 (BE) | `mips64-linux-ohos` | MIPS 64位大端 |
| MIPS (LE) | `mipsel-linux-ohos` | MIPS 32位小端 |
| MIPS (BE) | `mips-linux-ohos` | MIPS 32位大端 |

## 补丁说明

项目包含的主要补丁：

1. **0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch**
   - 添加 OHOS 目标支持
   - 支持多架构
   - musl libc 集成

2. **Alpine Linux 补丁系列**
   - 安全加固（PIE, SSP, FORTIFY_SOURCE）
   - musl libc 兼容性
   - 各种 bug 修复

## 编译示例

### 简单的 Hello World

```bash
# 编写源码
cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello, OpenHarmony!\n");
    return 0;
}
EOF

# 编译（假设有 sysroot）
aarch64-linux-ohos-gcc \
    --sysroot=/path/to/ohos-sysroot \
    -o hello \
    hello.c

# 如果没有 sysroot（静态链接）
aarch64-linux-ohos-gcc \
    -static \
    -o hello \
    hello.c
```

### C++ 程序

```bash
cat > hello.cpp << 'EOF'
#include <iostream>
int main() {
    std::cout << "Hello, OpenHarmony C++!" << std::endl;
    return 0;
}
EOF

aarch64-linux-ohos-g++ \
    --sysroot=/path/to/ohos-sysroot \
    -o hello \
    hello.cpp
```

## 故障排除

### 问题：configure 失败

```bash
# 确保已安装所有依赖
sudo apt-get install -y build-essential bison flex texinfo gawk zip \
    libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev

# 清理并重试
./build.sh clean
./build.sh
```

### 问题：链接失败

```bash
# 确保指定了正确的 sysroot
./build.sh --sysroot=/path/to/correct/sysroot

# 或使用静态链接
aarch64-linux-ohos-gcc -static ...
```

### 问题：找不到头文件

```bash
# 检查 sysroot 结构
ls /path/to/sysroot/usr/include/

# 确保 sysroot 包含必要的头文件
# 特别是 musl 的头文件
```

### 问题：构建时间过长

```bash
# 增加并行任务数
./build.sh --jobs=16

# 或仅构建需要的语言
./build.sh --enable-languages=c,c++
```

## 目录结构

```
ohos-gcc/
├── build.sh                    # 主构建脚本
├── BUILD_OHOS.md              # 本文档
├── README.md                  # 项目说明
├── patches/                   # 补丁目录
│   ├── 0001-Add-OpenHarmony-OHOS-*.patch
│   ├── 0002-gcc-poison-system-directories.patch
│   └── ...
├── gcc-15.2.0/               # GCC 源码（下载后）
├── build-ohos/               # 构建目录
└── install/                  # 默认安装目录
```

## 参考资料

- [GCC 官方文档](https://gcc.gnu.org/onlinedocs/)
- [OpenHarmony 官网](https://www.openharmony.cn/)
- [Alpine Linux GCC](https://git.alpinelinux.org/aports/tree/main/gcc)
- [musl libc](https://musl.libc.org/)

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

GCC 基于 GPL-3.0 许可证。本构建脚本遵循相同许可证。

## 致谢

本项目基于 Alpine Linux 的 GCC APKBUILD 脚本改编，感谢 Alpine Linux 社区的贡献。
