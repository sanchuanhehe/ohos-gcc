# GCC for OpenHarmony (OHOS)

<p align="center">
  <strong>为 OpenHarmony 操作系统构建完整的 GCC 工具链</strong>
</p>

<p align="center">
  <a href="https://github.com/sanchuanhehe/ohos-gcc/actions/workflows/build.yml">
    <img src="https://github.com/sanchuanhehe/ohos-gcc/actions/workflows/build.yml/badge.svg" alt="CI Build">
  </a>
  <a href="https://github.com/sanchuanhehe/ohos-gcc/actions/workflows/lint.yml">
    <img src="https://github.com/sanchuanhehe/ohos-gcc/actions/workflows/lint.yml/badge.svg" alt="Lint">
  </a>
  <a href="https://github.com/sanchuanhehe/ohos-gcc/actions/workflows/test.yml">
    <img src="https://github.com/sanchuanhehe/ohos-gcc/actions/workflows/test.yml/badge.svg" alt="Test">
  </a>
  <img src="https://img.shields.io/badge/GCC-15.2.0-blue" alt="GCC Version">
  <img src="https://img.shields.io/badge/Binutils-2.43-green" alt="Binutils Version">
  <img src="https://img.shields.io/badge/License-GPL--3.0-orange" alt="License">
</p>

---

## 📋 项目简介

本项目提供完整的构建脚本，用于为 **OpenHarmony (OHOS)** 操作系统编译 GCC 工具链。基于 Alpine Linux 的 GCC APKBUILD 构建系统，支持完整的三阶段构建流程。

### 🎯 构建阶段

| 阶段 | 名称 | 描述 |
|:---:|------|------|
| **Stage 1** | 交叉编译器 | 在 Linux 主机上运行，生成 OHOS 目标代码 |
| **Stage 2** | Canadian Cross | 在 Linux 上构建，生成在 OHOS 上运行的原生编译器 |
| **Stage 3** | 原生自举 | 在 OHOS 设备上使用 Stage 2 编译器重新编译自身 |

### ✨ 主要特性

| 特性 | 描述 |
|------|------|
| 🔧 **GCC 15.2.0 + Binutils 2.43** | 最新的编译器和二进制工具 |
| 🖥️ **多架构支持** | AArch64、x86_64、ARM、ARM HF、RISC-V 64、MIPS |
| 📚 **musl libc** | 轻量级标准 C 库支持 |
| 🔒 **安全特性** | 默认启用 PIE（位置无关可执行）和 SSP（栈保护） |
| 🔄 **Canadian Cross** | 支持构建原生 OHOS 编译器 |
| 📦 **自动下载 NDK** | 自动获取 sysroot 依赖 |
| 🚀 **CI/CD** | GitHub Actions 持续集成与交付 |
| 🛠️ **辅助工具** | 构建 make、bash、gawk、patch 等原生工具 |

## 🚀 快速开始

### 📋 系统要求

- **操作系统**: Linux (Ubuntu 20.04+, Debian 11+, Fedora 36+)
- **磁盘空间**: 至少 20GB 可用空间
- **内存**: 建议 8GB+ RAM
- **CPU**: 建议 4 核以上（并行编译）

### 📦 安装依赖

<details>
<summary><b>Ubuntu / Debian</b></summary>

```bash
sudo apt-get update
sudo apt-get install -y build-essential bison flex texinfo gawk zip unzip \
    libgmp-dev libmpfr-dev libmpc-dev zlib1g-dev wget git curl xz-utils
```

</details>

<details>
<summary><b>Fedora / RHEL / CentOS</b></summary>

```bash
sudo dnf install -y gcc gcc-c++ bison flex texinfo gawk zip unzip \
    gmp-devel mpfr-devel libmpc-devel zlib-devel wget git curl xz
```

</details>

<details>
<summary><b>Arch Linux</b></summary>

```bash
sudo pacman -S base-devel bison flex texinfo gawk zip unzip gmp mpfr libmpc wget git
```

</details>

### 🔨 Stage 1: 构建交叉编译器

```bash
# 克隆仓库
git clone https://github.com/sanchuanhehe/ohos-gcc.git
cd ohos-gcc

# AArch64 交叉编译器（推荐）
./build.sh --target=aarch64-linux-ohos --prefix=./install all

# 或 x86_64 交叉编译器
./build.sh --target=x86_64-linux-ohos --prefix=./install all
```

### 🔄 Stage 2: 构建原生 OHOS 编译器（Canadian Cross）

```bash
# 需要先完成 Stage 1
./build.sh \
    --build=x86_64-linux-gnu \
    --host=aarch64-linux-ohos \
    --target=aarch64-linux-ohos \
    --stage1=./install \
    --prefix=./install-stage2 \
    all
```

### ✅ 测试工具链

```bash
# 测试交叉编译器
./test-toolchain.sh ./install aarch64-linux-ohos

# 简单测试
./install/bin/aarch64-linux-ohos-gcc --version
```

## 📖 构建类型详解

### Stage 1: 交叉编译器

在 Linux 主机上运行，生成 OHOS 目标代码。这是最基础的构建步骤。

```
┌─────────────────────────────────────────────────────────────┐
│  构建机器 (BUILD)    →    运行机器 (HOST)    →    目标 (TARGET)    │
│  x86_64-linux-gnu         x86_64-linux-gnu         aarch64-linux-ohos  │
└─────────────────────────────────────────────────────────────┘
```

```bash
./build.sh --target=aarch64-linux-ohos --prefix=/opt/ohos-gcc-stage1 all
```

### Stage 2: Canadian Cross（原生编译器）

使用 Stage 1 交叉编译器构建，生成在 OHOS 上运行的原生编译器。

```
┌─────────────────────────────────────────────────────────────┐
│  构建机器 (BUILD)    →    运行机器 (HOST)   →   目标 (TARGET)   │
│  x86_64-linux-gnu   aarch64-linux-ohos  aarch64-linux-ohos  │
└─────────────────────────────────────────────────────────────┘
```

```bash
./build.sh \
    --build=x86_64-linux-gnu \
    --host=aarch64-linux-ohos \
    --target=aarch64-linux-ohos \
    --stage1=/opt/ohos-gcc-stage1 \
    --prefix=/opt/ohos-gcc-stage2 \
    all
```

### Stage 3: 原生自举

在 OHOS 设备上使用 Stage 2 编译器重新编译自身，验证工具链完整性。

```
┌─────────────────────────────────────────────────────────────┐
│  构建机器 (BUILD)    →    运行机器 (HOST)  →   目标 (TARGET)    │
│  aarch64-linux-ohos aarch64-linux-ohos  aarch64-linux-ohos  │
└─────────────────────────────────────────────────────────────┘
```

```bash
# 在 OHOS 设备上运行
./build.sh \
    --build=aarch64-linux-ohos \
    --host=aarch64-linux-ohos \
    --target=aarch64-linux-ohos \
    --stage2=/opt/ohos-gcc-stage2 \
    --prefix=/opt/ohos-gcc \
    all
```

## 🖥️ 支持的目标架构

| 架构 | 目标三元组 | Stage 1 | Stage 2 | Stage 3 | 说明 |
|:----:|-----------|:-------:|:-------:|:-------:|------|
| **AArch64** | `aarch64-linux-ohos` | ✅ | ✅ | ✅ | ARM 64位（推荐，主流 OHOS 设备） |
| **x86_64** | `x86_64-linux-ohos` | ✅ | ✅ | ✅ | Intel/AMD 64位 |
| **ARM** | `arm-linux-ohos` | ✅ | 🔄 | 🔄 | ARM 32位软浮点 |
| **ARM HF** | `armhf-linux-ohos` | ✅ | 🔄 | 🔄 | ARM 32位硬浮点 |
| **RISC-V 64** | `riscv64-linux-ohos` | ✅ | 🔄 | 🔄 | RISC-V 64位 |
| **MIPS64** | `mips64el-linux-ohos` | ✅ | 🔄 | 🔄 | MIPS 64位小端 |

> **图例**: ✅ 完全支持 | 🔄 实验性支持

## 📝 命令参考

### 构建命令

```bash
./build.sh [选项] [命令]

命令:
  prepare_ndk      下载并设置 NDK sysroot
  prepare          准备所有源码（NDK + binutils + GCC）
  binutils         仅构建 binutils
  configure        配置 GCC
  build            编译 GCC
  install          安装 GCC
  all              完整构建流程（默认）
  clean            清理构建目录
```

### 选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `--target=TARGET` | 目标三元组 | `aarch64-linux-ohos` |
| `--host=HOST` | 主机三元组（编译器运行平台） | 自动检测 |
| `--build=BUILD` | 构建机器三元组 | 自动检测 |
| `--prefix=PATH` | 安装路径 | `./install` |
| `--sysroot=PATH` | Sysroot 路径 | `ndk/sysroot/TARGET` |
| `--stage1=PATH` | Stage 1 安装路径（Stage 2 需要） | - |
| `--stage2=PATH` | Stage 2 安装路径（Stage 3 需要） | - |
| `--jobs=N` | 并行任务数 | `$(nproc)` |
| `--enable-languages=LIST` | 启用的语言 | `c,c++` |
| `--relocatable-sysroot` | 使用相对 sysroot 路径（可分发） | `no` |

## 🛠️ 辅助工具构建

`build-tools.sh` 脚本用于构建在 OHOS 上运行的原生工具：

```bash
# 构建 make, bash, gawk, patch 等工具
./build-tools.sh --target=aarch64-linux-ohos --stage1=./install

# 支持的工具
# - GNU Make 4.4.1
# - Bash 5.2.32
# - GNU Awk 5.3.0
# - Patch 2.7.6
# - ncurses 6.4 (bash 依赖)
```

## 📁 项目结构

```
ohos-gcc/
├── 📄 build.sh                 # 主构建脚本（GCC + Binutils）
├── 📄 build-tools.sh           # 辅助工具构建脚本（make, bash 等）
├── 📄 build-examples.sh        # 交互式示例脚本
├── 📄 test-toolchain.sh        # 工具链测试脚本
├── 📄 README.md                # 项目说明文档
├── 📄 BUILD_OHOS.md            # 详细构建指南
├── 📄 CONTRIBUTING.md          # 贡献指南
│
├── 📁 gcc-patches/             # GCC OHOS 支持补丁 (42 个)
│   ├── 0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch
│   ├── 0002-gcc-poison-system-directories.patch
│   ├── ... (安全加固、musl 兼容性等)
│   └── 0042-genmatch-fmemopen-fflush-before-fclose.patch
│
├── 📁 binutils-patches/        # Binutils 补丁
│   └── 0001-Revert-PR25882-.gnu.attributes-are-not-checked-for-s.patch
│
├── 📁 sysroot-patches/         # NDK sysroot 补丁
│   ├── fortify-gcc-compat.patch
│   ├── string-gcc.patch
│   └── sys-sysinfo.patch
│
├── 📁 config/                  # 配置文件（config.sub 等）
│
├── 📁 .github/workflows/       # CI/CD 配置
│   ├── build.yml               # 主构建工作流
│   ├── lint.yml                # 代码检查
│   ├── test.yml                # 测试工作流
│   └── scheduled.yml           # 定时构建
│
├── 📁 ndk/                     # NDK sysroot（自动下载）
├── 📁 gcc-15.2.0/              # GCC 源码
├── 📁 binutils-2.43/           # Binutils 源码
├── 📁 build-ohos/              # GCC 构建目录
├── 📁 build-binutils/          # Binutils 构建目录
├── 📁 build-tools/             # 辅助工具构建目录
├── 📁 install/                 # Stage 1 安装目录
├── 📁 install-tools/           # 辅助工具安装目录
└── 📁 downloads/               # 下载缓存目录
```

## ⚙️ 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `CTARGET` | 目标三元组 | `aarch64-linux-ohos` |
| `CHOST` | 主机三元组 | `aarch64-linux-ohos` |
| `CBUILD` | 构建机器三元组 | `x86_64-linux-gnu` |
| `INSTALL_PREFIX` | 安装路径 | `/opt/ohos-gcc` |
| `STAGE1_PREFIX` | Stage 1 路径 | `./install` |
| `STAGE2_PREFIX` | Stage 2 路径 | `./install-stage2` |
| `SYSROOT` | Sysroot 路径 | `./ndk/sysroot` |
| `NDK_URL` | NDK 下载地址 | LLVM-19 官方地址 |
| `JOBS` | 并行任务数 | `$(nproc)` |

## ❓ 常见问题

<details>
<summary><b>Q: Stage 2 构建失败，提示找不到编译器？</b></summary>

**A:** 确保以下条件：

1. Stage 1 已成功构建完成
2. `--stage1` 路径正确指向 Stage 1 安装目录
3. 如果重新构建，先清理目标目录：

   ```bash
   rm -rf install-stage2 build-ohos build-binutils
   ```

</details>

<details>
<summary><b>Q: 构建需要多长时间？</b></summary>

**A:** 根据硬件配置不同，构建时间如下：

| 配置 | Stage 1 | Stage 2 | Stage 3 |
|------|---------|---------|---------|
| 8 核 CPU, 16GB RAM | ~30-60 分钟 | ~45-90 分钟 | ~60-120 分钟 |
| 16 核 CPU, 32GB RAM | ~15-30 分钟 | ~25-45 分钟 | ~30-60 分钟 |
| 32 核 CPU, 64GB RAM | ~10-15 分钟 | ~15-25 分钟 | ~20-30 分钟 |

</details>

<details>
<summary><b>Q: 如何使用编译好的工具链？</b></summary>

**A:**

```bash
# Stage 1 交叉编译
export PATH=/opt/ohos-gcc-stage1/bin:$PATH
aarch64-linux-ohos-gcc -o hello hello.c

# 查看目标信息
aarch64-linux-ohos-gcc -v

# 查看支持的架构选项
aarch64-linux-ohos-gcc --target-help
```

</details>

<details>
<summary><b>Q: 支持哪些编程语言？</b></summary>

**A:** 默认支持 C 和 C++。可通过 `--enable-languages` 启用其他语言：

```bash
# 启用 C, C++, Fortran
./build.sh --enable-languages=c,c++,fortran ...

# 支持的语言列表
# - c (默认)
# - c++ (默认)
# - fortran
# - go
# - objc
# - d
# - ada
# - jit
```

</details>

<details>
<summary><b>Q: 如何在没有网络的环境下构建？</b></summary>

**A:** 提前下载所需文件到 `downloads/` 和 `ndk/` 目录：

```bash
# 1. 在有网络的机器上下载
./build.sh prepare_ndk
./build.sh prepare

# 2. 打包传输到离线机器
tar czvf ohos-gcc-sources.tar.gz gcc-15.2.0/ binutils-2.43/ ndk/ downloads/

# 3. 在离线机器上构建
tar xzvf ohos-gcc-sources.tar.gz
./build.sh --target=aarch64-linux-ohos all
```

</details>

<details>
<summary><b>Q: 如何调试构建问题？</b></summary>

**A:**

```bash
# 查看详细构建日志
./build.sh --target=aarch64-linux-ohos all 2>&1 | tee build.log

# 分步构建以定位问题
./build.sh prepare
./build.sh binutils
./build.sh configure
./build.sh build
./build.sh install

# 检查配置
cat build-ohos/config.log | grep -i error
```

</details>

## 🔄 CI/CD

本项目使用 GitHub Actions 进行持续集成：

| 工作流 | 触发条件 | 功能 |
|--------|----------|------|
| **build.yml** | Push/PR | 构建 Stage 1/2 工具链 |
| **lint.yml** | Push/PR | ShellCheck 代码检查 |
| **test.yml** | Push/PR | 工具链功能测试 |
| **scheduled.yml** | 每周 | 定时构建与验证 |

构建产物可从 Actions 页面的 Artifacts 下载。

## 🐳 Docker 构建

推荐使用 Docker 进行隔离构建，特别是在鸿蒙设备上开发时：

```bash
# 使用 openharmony docker 镜像
# 参考: https://github.com/hqzing/docker-mini-openharmony

# 或使用本项目的 Dockerfile
cd docker
docker-compose up -d
docker exec -it ohos-gcc-builder bash
./build.sh --target=aarch64-linux-ohos all
```

## 🤝 贡献

欢迎贡献！请查看 [CONTRIBUTING.md](CONTRIBUTING.md) 了解详情。

### 贡献方式

- 🐛 报告 Bug
- 💡 提出功能建议
- 📝 改进文档
- 🔧 提交代码修复
- ✨ 添加新特性

## 📜 许可证

| 组件 | 许可证 |
|------|--------|
| GCC | GPL-3.0-or-later with GCC Runtime Library Exception |
| Binutils | GPL-3.0-or-later |
| 本项目脚本 | GPL-3.0 |

## 🙏 致谢

- [Alpine Linux](https://alpinelinux.org/) - 构建脚本参考
- [GCC Project](https://gcc.gnu.org/) - GNU 编译器集合
- [GNU Binutils](https://sourceware.org/binutils/) - 二进制工具
- [OpenHarmony](https://www.openharmony.cn/) - 目标操作系统
- [musl libc](https://musl.libc.org/) - 轻量级 C 标准库
- [docker-mini-openharmony](https://github.com/hqzing/docker-mini-openharmony) - Docker 开发环境

## 🔗 相关链接

| 资源 | 链接 |
|------|------|
| OpenHarmony 官网 | <https://www.openharmony.cn/> |
| GCC 官方文档 | <https://gcc.gnu.org/onlinedocs/> |
| Binutils 文档 | <https://sourceware.org/binutils/docs/> |
| musl libc 文档 | <https://musl.libc.org/doc/1.1.24/manual.html> |
| Canadian Cross 编译 | <https://clfs.org/view/clfs-3.0.0-sysvinit/mips64-64/cross-tools/cross-gcc.html> |

---

<p align="center">
  <b>⚠️ 注意</b>: 这是一个社区项目，与 OpenHarmony 官方无关。
</p>

<p align="center">
  Made with ❤️ for the OpenHarmony Community
</p>
