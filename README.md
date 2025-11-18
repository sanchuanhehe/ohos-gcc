# GCC for OpenHarmony (OHOS)

OpenHarmony 的 GCC 交叉编译工具链构建脚本，基于 Alpine Linux 的 GCC APKBUILD 改编。

> 进展：施工中

## 项目简介

本项目提供了一个完整的构建脚本，用于为 OpenHarmony (OHOS) 操作系统编译 GCC 交叉编译工具链。支持多种目标架构，包括 AArch64、ARM、x86/x86_64、RISC-V 和 MIPS。

### 主要特性

- ✅ 基于 GCC 15.2.0
- ✅ 支持多架构（AArch64、ARM、x86/x86_64、RISC-V、MIPS）
- ✅ 使用 musl libc
- ✅ 包含 OHOS 特定补丁和优化
- ✅ 默认启用安全特性（PIE、SSP）
- ✅ 灵活的构建配置
- ✅ 完整的文档和示例

## 快速开始

### 1. 安装依赖

```bash
# Ubuntu/Debian
sudo apt-get install -y build-essential bison flex texinfo gawk zip \
    libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev wget

# Fedora/RHEL
sudo dnf install -y gcc gcc-c++ bison flex texinfo gawk zip \
    gmp-devel mpfr-devel libmpc-devel zlib-devel wget
```

### 2. 构建工具链

#### 使用交互式示例脚本（推荐）

```bash
./build-examples.sh
```

#### 手动构建

```bash
# AArch64 (推荐用于 OHOS 设备)
./build.sh --target=aarch64-linux-ohos --prefix=/opt/ohos-gcc

# ARM 32位
./build.sh --target=arm-linux-ohos --prefix=/opt/ohos-gcc-arm

# x86_64
./build.sh --target=x86_64-linux-ohos --prefix=/opt/ohos-gcc-x86_64

# RISC-V 64位
./build.sh --target=riscv64-linux-ohos --prefix=/opt/ohos-gcc-riscv64
```

### 3. 测试工具链

```bash
# 测试已安装的工具链
./test-toolchain.sh /opt/ohos-gcc aarch64-linux-ohos
```

### 4. 使用工具链

```bash
# 添加到 PATH
export PATH=/opt/ohos-gcc/bin:$PATH

# 编译示例程序
cat > hello.c << 'EOF'
#include <stdio.h>
int main() {
    printf("Hello, OpenHarmony!\n");
    return 0;
}
EOF

aarch64-linux-ohos-gcc -o hello hello.c
```

## 文档

- [**BUILD_OHOS.md**](BUILD_OHOS.md) - 完整的构建指南和文档
- [**CONTRIBUTING.md**](CONTRIBUTING.md) - 贡献指南
- [**patches/APKBUILD**](patches/APKBUILD) - Alpine Linux 原始 APKBUILD 参考

## 项目结构

```
ohos-gcc/
├── build.sh                  # 主构建脚本
├── build-examples.sh         # 交互式示例脚本
├── test-toolchain.sh         # 工具链测试脚本
├── BUILD_OHOS.md            # 详细构建文档
├── README.md                # 本文件
├── patches/                 # GCC 补丁
│   ├── 0001-Add-OpenHarmony-OHOS-*.patch  # OHOS 支持补丁
│   └── 00*.patch            # Alpine Linux 补丁系列
└── gcc-15.2.0/              # GCC 源码（自动下载）
```

## 支持的目标架构

| 架构 | 目标三元组 | 说明 |
|------|-----------|------|
| AArch64 | `aarch64-linux-ohos` | ARM 64位（推荐） |
| ARM | `arm-linux-ohos` | ARM 32位软浮点 |
| ARM HF | `armhf-linux-ohos` | ARM 32位硬浮点 |
| x86_64 | `x86_64-linux-ohos` | Intel/AMD 64位 |
| x86 | `i686-linux-ohos` | Intel/AMD 32位 |
| RISC-V | `riscv64-linux-ohos` | RISC-V 64位 |
| MIPS | `mips*-linux-ohos` | MIPS 32/64位 |

## 高级用法

### 指定 Sysroot

```bash
./build.sh \
    --target=aarch64-linux-ohos \
    --prefix=/opt/ohos-gcc \
    --sysroot=/path/to/ohos-sysroot
```

### 自定义语言支持

```bash
# 仅 C 和 C++
./build.sh --enable-languages=c,c++

# 添加 Fortran
./build.sh --enable-languages=c,c++,fortran
```

### 并行构建

```bash
# 使用 8 个并行任务
./build.sh --jobs=8
```

### 分步构建

```bash
./build.sh prepare    # 准备源码和补丁
./build.sh configure  # 配置构建
./build.sh build      # 编译
./build.sh install    # 安装
./build.sh clean      # 清理
```

## 补丁说明

### OHOS 补丁

`0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch` 添加了对 OpenHarmony 的全面支持：

- OHOS 目标识别（config.sub）
- 多架构配置（config.gcc）
- 动态链接器路径
- musl libc 集成
- 架构特定头文件和库路径

### Alpine Linux 补丁

来自 Alpine Linux 的补丁系列，包括：

- 安全加固（PIE、SSP、FORTIFY_SOURCE）
- musl libc 兼容性修复
- 各种 bug 修复和优化

## 常见问题

### Q: 构建失败怎么办？

A: 请检查：
1. 是否安装了所有依赖
2. 磁盘空间是否充足（至少需要 10GB）
3. 查看 BUILD_OHOS.md 中的故障排除部分

### Q: 如何交叉编译程序？

A: 使用 `--sysroot` 参数指定目标系统的根文件系统：

```bash
aarch64-linux-ohos-gcc \
    --sysroot=/path/to/ohos-sysroot \
    -o myprogram \
    myprogram.c
```

### Q: 支持哪些语言？

A: 默认支持 C 和 C++。可以通过 `--enable-languages` 参数启用其他语言（Fortran、Go、D、Ada、Objective-C）。

### Q: 编译时间多长？

A: 取决于硬件配置和启用的语言。在现代 8 核处理器上：
- C/C++ only: 约 30-60 分钟
- 所有语言: 约 2-3 小时

## 贡献

欢迎大家参与贡献！目前已经完成了 sysroot 的适配和部分其它部分的简单适配，欢迎提交 PR。

详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

- GCC: GPL-3.0
- 本项目构建脚本: GPL-3.0
- OHOS 补丁: 与 GCC 相同的许可证

## 致谢

- [Alpine Linux](https://alpinelinux.org/) - APKBUILD 脚本基础
- [GCC Project](https://gcc.gnu.org/) - 编译器本身
- [OpenHarmony](https://www.openharmony.cn/) - 目标操作系统
- [musl libc](https://musl.libc.org/) - C 标准库

## 相关链接

- [OpenHarmony 官网](https://www.openharmony.cn/)
- [GCC 官方文档](https://gcc.gnu.org/onlinedocs/)
- [Alpine Linux GCC](https://git.alpinelinux.org/aports/tree/main/gcc)
- [musl libc](https://musl.libc.org/)

---

**注意**: 这是一个社区项目，与 OpenHarmony 官方无关。如有问题请通过 Issue 反馈。

