# 贡献指南

感谢您对 FocusGuard 项目的关注！我们欢迎任何形式的贡献。

## 如何贡献

### 报告 Bug

如果您发现了 Bug，请通过 [Issue Tracker](../../issues) 报告：

1. 搜索现有的 issues，确认问题未被报告
2. 创建新 Issue，使用 "Bug Report" 模板
3. 提供详细的复现步骤、预期行为和实际行为
4. 附上相关的日志或截图（如果适用）

### 提出新功能

如果您有新的功能建议：

1. 搜索现有的 issues 和 discussions
2. 创建新的 Feature Request
3. 清晰描述功能需求和使用场景
4. 说明为什么这个功能对用户有价值

### 提交代码

#### 准备工作

1. Fork 本仓库
2. 创建您的特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交您的更改 (`git commit -m 'feat: add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

#### 代码规范

- 使用 Swift 5.9+ 语法
- 遵循现有代码风格
- 添加必要的注释
- 确保代码通过编译
- 测试您的更改

#### Commit Message 规范

我们使用语义化提交信息（Semantic Commits）：

```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型 (type):**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响代码运行）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例：**
```
feat(ai): add support for GLM-4V API

- Implement new API client for GLM-4V
- Add configuration settings in SettingsView
- Update documentation

Closes #123
```

## 开发环境

### 系统要求

- macOS 13.0+
- Xcode 15.0+ 或 Swift 5.9+
- Swift Package Manager

### 构建项目

```bash
# 克隆仓库
git clone https://github.com/your-username/FocusGuard.git
cd FocusGuard

# 安装依赖
swift package resolve

# 编译
swift build

# 运行
swift run
```

### 构建应用包

```bash
# 构建 .app 包
./build-app.sh release

# 安装到系统
./install.sh
```

详细说明见 [INSTALLATION.md](INSTALLATION.md)

## 项目结构

```
Sources/
├── App/              # 应用入口
├── UI/               # 用户界面
├── Core/             # 核心逻辑
└── Services/         # 各种服务
Tests/                # 测试代码
docs/                 # 文档
Resources/            # 资源文件
```

## 测试

```bash
# 运行所有测试
swift test

# 运行特定测试
swift test --filter TestClassName.testMethodName
```

## 行为准则

- 尊重所有贡献者
- 使用包容和友好的语言
- 接受建设性的批评
- 关注对社区最有利的事情

## 获取帮助

如果您有任何问题：

1. 查看 [README](README.md)
2. 搜索 [Issues](../../issues) 和 [Discussions](../../discussions)
3. 创建新的 Discussion 提问

感谢您的贡献！
