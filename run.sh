#!/bin/bash

echo "🚀 FocusGuard 启动脚本"
echo "========================"

if [ ! -f "Package.swift" ]; then
    echo "❌ 错误: 请在FocusGuard项目目录中运行此脚本"
    exit 1
fi

echo "📦 正在编译..."
swift build -c debug

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功!"
APP_DIR=".build/FocusGuard.app"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"

echo "📦 正在打包为 .app（确保系统正确处理摄像头权限）..."
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp ".build/arm64-apple-macosx/debug/FocusGuard" "$APP_MACOS/FocusGuard"
cp "Resources/Info.plist" "$APP_CONTENTS/Info.plist"

echo ""
echo "📝 使用说明:"
echo "1. 应用启动后会在菜单栏显示图标"
echo "2. 点击图标打开菜单"
echo "3. 点击 'Start' 开始专注监测"
echo "4. 点击 'Settings...' 配置AI API"
echo ""
echo "⚠️  首次使用需要配置AI API Key:"
echo "   - GLM-4V: https://open.bigmodel.cn"
echo "   - Qwen2.5-VL: https://dashscope.aliyuncs.com"
echo "   - Ollama: 本地运行 http://localhost:11434"
echo ""
echo "🎯 启动应用..."
echo ""

open "$APP_DIR"
