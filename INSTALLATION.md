# FocusGuard 安装和使用指南

## 快速安装

### 方式1：使用安装脚本（推荐）

```bash
# 1. 构建应用
./build-app.sh release

# 2. 安装应用
./install.sh
```

安装脚本会询问您想安装到哪里：

- **选项1**：`/Applications`（系统级，推荐）
  - 会在 Launchpad 和访达的"应用程序"中显示
  - 所有用户都能看到

- **选项2**：`~/Applications`（用户级）
  - 只有当前用户能看到
  - 通过 Cmd+Shift+G 前往 ~/Applications 找到

### 方式2：手动安装

```bash
# 1. 构建应用
./build-app.sh release

# 2. 移动应用到系统级（推荐）
mv FocusGuard.app /Applications/

# 或者移动到用户级
mkdir -p ~/Applications
mv FocusGuard.app ~/Applications/
```

---

## 启动应用

### 系统级安装（/Applications）

1. **Spotlight 搜索**（最快）
   - 按 `Cmd + Space`
   - 输入 "FocusGuard"
   - 按回车

2. **Launchpad**
   - 点击 Dock 中的 Launchpad
   - 找到并点击 FocusGuard

3. **访达的「应用程序」文件夹**
   - 打开访达 → 左侧点击「应用程序」
   - 双击 FocusGuard.app

4. **添加到 Dock（推荐）**
   - 在 Dock 中右键 FocusGuard 图标
   - 选择「选项」→「保留在程序坞」

### 用户级安装（~/Applications）

1. **Spotlight 搜索**
   - 按 `Cmd + Space` → 输入 "FocusGuard" → 回车

2. **通过「前往文件夹」**
   - 打开访达
   - 按 `Cmd + Shift + G`
   - 输入 `~/Applications`
   - 双击 FocusGuard.app

3. **添加到 Dock**
   - 打开 FocusGuard
   - 在 Dock 中右键图标 → 选项 → 保留在程序坞

---

## 首次使用配置

### 1. 授予摄像头权限

**系统设置** → **隐私与安全性** → **摄像头** → 勾选 FocusGuard

### 2. 配置 AI API

1. 点击菜单栏的 FocusGuard 图标
2. 选择 "Settings..."
3. 选择 AI Provider：

**选项1：GLM-4V（智谱AI）**
- Provider: GLM-4V
- API Key: 从 https://open.bigmodel.cn 获取

**选项2：Qwen2.5-VL（阿里云）**
- Provider: Qwen2.5-VL
- API Key: 从 https://dashscope.aliyuncs.com 获取

**选项3：Ollama（本地）**
- Provider: Ollama
- Base URL: http://localhost:11434/v1
- Model: llava 或其他视觉模型
- 注意：需要先安装并运行 Ollama

---

## 开始使用

1. 点击菜单栏的 FocusGuard 图标
2. 点击 "Start" 开始专注监测
3. 应用会自动检测您的专注状态
4. 状态变化时会有相应提醒

---

## 常见问题

### Q: 提示应用已损坏？
A: 运行以下命令重新签名：
```bash
# 系统级安装
xattr -cr /Applications/FocusGuard.app
codesign --deep --force --sign - /Applications/FocusGuard.app

# 用户级安装
xattr -cr ~/Applications/FocusGuard.app
codesign --deep --force --sign - ~/Applications/FocusGuard.app
```

### Q: 应用无法启动？
A: 确保已授予摄像头权限，并检查 macOS 版本（需要 macOS 13+）

### Q: 如何添加到 Dock？
A: 启动应用后，在 Dock 中右键图标 → 选项 → 保留在程序坞

### Q: 如何卸载？
A:
```bash
# 系统级安装
sudo rm -rf /Applications/FocusGuard.app

# 用户级安装
rm -rf ~/Applications/FocusGuard.app

# 清理偏好设置
rm ~/Library/Preferences/com.focusguard.app.plist
```

### Q: 在访达的"应用程序"中看不到？
A: 如果选择用户级安装（~/Applications），不会在访达的系统级"应用程序"中显示。请使用 Spotlight 搜索或通过 Cmd+Shift+G 前往 ~/Applications。

---

## 脚本说明

### build-app.sh
构建 .app 应用包
```bash
./build-app.sh release  # 或 debug
```

### install.sh
交互式安装脚本，会询问安装位置
```bash
./install.sh
```

### quick-start.sh
快速启动应用（需要先安装）
```bash
./quick-start.sh
```

---

## 注意事项

- 安装脚本使用 `mv` 命令移动应用，不会在项目目录保留副本
- 系统级安装（/Applications）需要管理员权限（sudo）
- 用户级安装（~/Applications）无需权限，但不在访达的系统级"应用程序"中显示
- 首次运行需要授予摄像头权限
