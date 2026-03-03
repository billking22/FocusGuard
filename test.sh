#!/bin/bash

# FocusGuard Test Script
# This script helps test FocusGuard with a mock configuration

echo "🧪 FocusGuard 测试脚本"
echo "======================="
echo ""

# Check if running from correct directory
if [ ! -f "Package.swift" ]; then
    echo "❌ 请在FocusGuard项目目录中运行此脚本"
    exit 1
fi

# Build the project
echo "📦 编译项目..."
swift build -c debug

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功"
echo ""

# Set default configuration for testing
echo "⚙️  设置测试配置..."
defaults write com.focusguard.app aiProvider -string "glm4v"
defaults write com.focusguard.app apiKey -string "test-api-key"
defaults write com.focusguard.app baseInterval -double 300
defaults write com.focusguard.app alertInterval -double 120
defaults write com.focusguard.app deepFocusInterval -double 480

echo "✅ 已设置默认配置:"
echo "   Provider: GLM-4V"
echo "   Base Interval: 5 minutes"
echo "   Alert Interval: 2 minutes"
echo ""

# Run the app
echo "🚀 启动 FocusGuard..."
echo ""
echo "操作指南:"
echo "1. 点击菜单栏绿色圆点图标"
echo "2. 点击 'Start' 开始监测"
echo "3. 点击 'Settings...' 修改配置"
echo "4. 点击 'Quit' 退出应用"
echo ""

.build/debug/FocusGuard
