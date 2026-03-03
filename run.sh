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

.build/arm64-apple-macosx/debug/FocusGuard
