# 贡献指南

感谢你对 ohos-gcc 项目的关注！我们欢迎各种形式的贡献。

## 目录

- [如何贡献](#如何贡献)
- [开发环境](#开发环境)
- [代码规范](#代码规范)
- [提交规范](#提交规范)
- [测试要求](#测试要求)
- [贡献领域](#贡献领域)
- [补丁提交流程](#补丁提交流程)
- [行为准则](#行为准则)

## 如何贡献

### 报告问题

如果你发现了 bug 或有功能建议，请通过 GitHub Issues 报告：

1. 搜索是否已有相关 issue
2. 创建新 issue，清楚描述问题：
   - 使用的 GCC 版本 (15.2.0)
   - 目标架构 (aarch64-linux-ohos 等)
   - 构建阶段 (Stage 1/2/3)
   - 复现步骤
   - 预期行为和实际行为
   - 相关日志和错误信息

**Issue 模板:**

```markdown
### 环境信息
- 操作系统: Ubuntu 22.04
- GCC 版本: 15.2.0
- 目标架构: aarch64-linux-ohos
- 构建阶段: Stage 1

### 问题描述
简要描述遇到的问题

### 复现步骤
1. 执行 `./build.sh --target=aarch64-linux-ohos all`
2. 等待构建...
3. 出现错误

### 错误日志
```

粘贴相关错误日志

```

### 预期行为
描述你期望的结果
```

### 提交代码

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'feat: Add some amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 开发环境

### Docker 开发环境（推荐）

目前鸿蒙电脑的权限限制较多，推荐使用 Docker 进行开发：

```bash
# 使用 openharmony docker 镜像
# 参考: https://github.com/hqzing/docker-mini-openharmony

docker pull hqzing/mini-openharmony
docker run -it -v $(pwd):/workspace hqzing/mini-openharmony bash
```

### 本地开发环境

**Ubuntu/Debian:**

```bash
sudo apt-get install -y \
    build-essential \
    git \
    shellcheck \
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
    curl
```

**Fedora/RHEL:**

```bash
sudo dnf install -y \
    gcc \
    gcc-c++ \
    git \
    ShellCheck \
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
    curl
```

## 代码规范

### Shell 脚本

- 使用 4 空格缩进
- 函数名使用下划线分隔（`my_function`）
- 局部变量使用小写（`local my_var`）
- 全局变量使用大写（`MY_GLOBAL_VAR`）
- 添加必要的注释
- 使用 `set -e` 确保错误时退出
- 使用 shellcheck 检查脚本

```bash
# 检查所有脚本
shellcheck build.sh build-tools.sh build-examples.sh test-toolchain.sh
```

**示例函数:**

```bash
# Good: 清晰的函数定义
my_function() {
    local input="$1"
    local result
    
    # 处理逻辑
    result=$(process "$input")
    
    echo "$result"
}
```

### 补丁文件

补丁文件应该：

- 有清晰的提交信息
- 包含 ChangeLog 条目
- 遵循 GCC 代码风格
- 在多个架构上测试

## 提交规范

### 提交信息格式

使用 [Conventional Commits](https://www.conventionalcommits.org/) 规范：

```
<类型>(<范围>): <简短描述>

<详细描述>

<相关 issue>
```

### 类型列表

| 类型 | 说明 |
|------|------|
| `feat` | 新功能 |
| `fix` | bug 修复 |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响功能）|
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `ci` | CI/CD 配置 |
| `chore` | 构建/工具链相关 |

### 示例

```
feat(arch): 添加 LoongArch 架构支持

- 添加 loongarch64-linux-ohos 目标
- 更新架构检测逻辑
- 添加 LoongArch 特定配置

Closes #123
```

类型包括：

- `feat`: 新功能
- `fix`: bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具链相关

示例：

```
feat: 添加 LoongArch 架构支持

- 添加 loongarch64-linux-ohos 目标
- 更新架构检测逻辑
- 添加 LoongArch 特定配置

Closes #123
```

## 测试要求

在提交 PR 之前，请确保：

1. ✅ 脚本通过 shellcheck 检查
2. ✅ 在至少一个架构上测试构建
3. ✅ 更新相关文档
4. ✅ 添加或更新测试用例

```bash
# 运行 shellcheck
shellcheck build.sh build-tools.sh build-examples.sh test-toolchain.sh

# 测试 Stage 1 构建
./build.sh --target=aarch64-linux-ohos --prefix=/tmp/test-gcc all

# 测试工具链
./test-toolchain.sh /tmp/test-gcc aarch64-linux-ohos

# 清理测试目录
rm -rf /tmp/test-gcc build-ohos build-binutils
```

### 快速测试（仅配置）

```bash
# 仅测试配置阶段（不完整构建）
./build.sh prepare
./build.sh configure
# 检查 build-ohos/config.log
```

## 贡献领域

我们特别欢迎以下方面的贡献：

### 🏗️ 架构支持

- 添加新架构支持（如 LoongArch）
- 优化现有架构配置
- 修复架构特定问题
- 添加架构测试

### 🔧 补丁维护

- 更新现有补丁以兼容新版本 GCC
- 添加新的 OHOS 特定优化
- 修复补丁相关问题
- 移植上游修复

### 📚 文档改进

- 改进构建文档
- 添加使用示例
- 完善故障排除指南
- 添加架构特定说明

### 🧪 测试

- 添加自动化测试
- 在不同平台上测试
- 报告测试结果
- 添加回归测试

### 🛠️ 工具改进

- 改进构建脚本
- 添加新的辅助工具
- 优化构建性能
- 改进错误处理

### 🐳 CI/CD

- 改进 GitHub Actions 工作流
- 添加新的测试矩阵
- 优化构建缓存
- 添加发布自动化

## 补丁提交流程

如果你要添加或修改 GCC 补丁：

### 1. 创建补丁

```bash
cd gcc-15.2.0
# 修改代码
git add .
git commit -m "你的修改说明"
git format-patch -1
```

### 2. 命名补丁

使用编号前缀：

```
0XXX-<简短描述>.patch
```

例如：

```
0001-Add-OpenHarmony-OHOS-target-support-to-GCC.patch
0042-Add-LoongArch-support.patch
```

### 3. 添加 ChangeLog

补丁应包含详细的 ChangeLog：

```diff
Subject: [PATCH] Add LoongArch support

This patch adds support for LoongArch architecture...

ChangeLog:

 * config.gcc: Add loongarch64-*-linux-ohos* target.
 * config/loongarch/loongarch-ohos.h: New file.
```

### 4. 测试补丁

```bash
# 应用补丁
cd gcc-15.2.0
patch -p1 < ../patches/0042-Add-LoongArch-support.patch

# 构建测试
cd ..
./build.sh --target=loongarch64-linux-ohos
```

## 行为准则

### 我们的承诺

为了营造开放和友好的环境，我们承诺：

- 使用友好和包容的语言
- 尊重不同的观点和经验
- 优雅地接受建设性批评
- 关注对社区最有利的事情
- 对其他社区成员表示同理心

### 不可接受的行为

- 使用性暗示的语言或图像
- 侮辱/贬损性评论和人身攻击
- 公开或私下骚扰
- 未经许可发布他人的私人信息
- 其他不道德或不专业的行为

## 获取帮助

如有问题，可以：

1. 查看 [BUILD_OHOS.md](BUILD_OHOS.md)
2. 搜索现有 Issues
3. 创建新 Issue 提问
4. 联系维护者

## 许可证

通过贡献代码，你同意你的贡献将在 GPL-3.0 许可证下发布。

---

再次感谢你的贡献！🎉
