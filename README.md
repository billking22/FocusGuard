# FocusGuard - 专注力管理助手

基于AI视觉分析的macOS菜单栏应用，帮助您建立深度工作习惯。

## ✨ 特性

- 🤖 **AI视觉分析**: 使用GLM-4V、Qwen2.5-VL或本地Ollama模型分析专注状态
- 📊 **智能监测**: 4种状态（正常/警觉/干预/深度专注）+ 自适应监测间隔
- 🔒 **隐私保护**: 图像仅内存处理，永不存储，纯文本统计
- 💡 **温和提醒**: 渐进式提醒策略，避免打扰心流状态
- 🔌 **系统感知**: 自动检测锁屏/解锁，智能暂停

## 🚀 快速开始

### 1. 安装依赖

```bash
cd FocusGuard
swift package resolve
```

### 2. 编译运行

```bash
swift build
.build/debug/FocusGuard
```

或生成Release版本:

```bash
swift build -c release
.build/release/FocusGuard
```

### 3. 配置AI API

首次运行时，点击菜单栏图标 → Settings，配置以下选项:

**AI Provider选项:**

1. **GLM-4V (智谱AI)**
   - Provider: GLM-4V
   - API Key: 从 https://open.bigmodel.cn 获取

2. **Qwen2.5-VL (阿里云)**
   - Provider: Qwen2.5-VL
   - API Key: 从 https://dashscope.aliyuncs.com 获取

3. **Ollama (本地)**
   - Provider: Ollama
   - Base URL: http://localhost:11434/v1
   - Model: llava 或其他视觉模型

## 🛠️ 开发

### 项目结构

```
Sources/
├── App/
│   └── Main.swift              # 应用入口
├── UI/
│   ├── MenuBarView.swift      # 菜单栏UI
│   └── SettingsView.swift     # 设置面板
├── Core/
│   ├── StateMachine.swift     # 状态机
│   ├── MonitorEngine.swift    # 监测引擎
│   └── AIPipeline.swift       # AI分析流水线
└── Services/
    ├── AIClient.swift         # AI API客户端
    ├── LocalAnalyzer.swift    # 本地视觉分析
    ├── CameraManager.swift    # 摄像头管理
    ├── SystemEventObserver.swift  # 系统事件监听
    └── DetectionStore.swift   # 数据存储
```

### 构建Xcode项目

```bash
swift package generate-xcodeproj
```

或使用Xcode直接打开Package.swift:

```bash
open Package.swift
```

## ⚙️ 配置项

### 监测间隔

- **Base Interval (T0)**: 正常监测间隔 (默认5分钟)
- **Alert Interval (T1)**: 警觉状态间隔 (默认2分钟)
- **Deep Focus Interval (T2)**: 深度专注间隔 (默认8分钟)

### AI设置

- **Timeout**: AI请求超时时间 (默认8秒)
- **Image Resolution**: 图像压缩分辨率 (默认640p)
- **Compression Quality**: 图像压缩质量 (默认60%)

### 通知设置

- **Voice**: 语音提醒开关
- **Volume**: 语音音量
- **Message**: 干预提醒文本

## 📄 技术方案

详细技术方案见 [docs/technical-spec-v1.md](docs/technical-spec-v1.md)

## 🔒 隐私说明

- 所有图像分析在内存中进行，永不存储到磁盘
- 仅保存文本统计信息（状态/置信度/时间戳）
- 支持纯本地AI模型（Ollama），无需网络

## 📝 License

本项目采用 MIT 许可证 - 详见 [LICENSE](LICENSE) 文件

Copyright © 2026 FocusGuard
