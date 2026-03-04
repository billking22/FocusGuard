#!/bin/bash

echo "📦 FocusGuard 安装脚本"
echo "======================"
echo ""

# 检查是否在项目目录
if [ ! -f "Package.swift" ]; then
    echo "❌ 错误: 请在 FocusGuard 项目目录中运行此脚本"
    exit 1
fi

# 检查 .app 是否存在
if [ ! -d "FocusGuard.app" ]; then
    echo "❌ 错误: 未找到 FocusGuard.app"
    echo "   请先运行: ./build-app.sh release"
    exit 1
fi

# 移除隔离属性
echo "🔓 移除 macOS 隔离属性..."
xattr -cr FocusGuard.app 2>/dev/null

# 临时签名（ad-hoc）
echo "✍️  添加临时签名..."
codesign --deep --force --sign - FocusGuard.app 2>/dev/null

if [ $? -ne 0 ]; then
    echo "⚠️  警告: 签名失败，但应用仍可能可以运行"
fi

# 选择安装位置
echo ""
echo "📍 选择安装位置:"
echo "   1. /Applications (系统级，推荐)"
echo "   2. ~/Applications (用户级)"
echo ""
read -p "请选择 [1-2，默认1]: " choice
choice=${choice:-1}

if [ "$choice" = "1" ]; then
    # 安装到系统 /Applications
    echo "📥 安装到 /Applications (系统级)..."

    # 检查是否需要 sudo
    if [ -w "/Applications" ]; then
        TARGET_DIR="/Applications"
    else
        echo "⚠️  需要 sudo 权限写入 /Applications"
        echo "   正在尝试使用 sudo..."
        if sudo mv FocusGuard.app /Applications/; then
            TARGET_DIR="/Applications"
        else
            echo "❌ 安装到 /Applications 失败"
            echo "💡 您可以尝试选项2（安装到 ~/Applications）"
            exit 1
        fi
    fi
else
    # 安装到用户 ~/Applications
    echo "📥 安装到 ~/Applications (用户级)..."
    mkdir -p ~/Applications 2>/dev/null
    TARGET_DIR="$HOME/Applications"
fi

# 删除旧版本（如果存在）
if [ -d "$TARGET_DIR/FocusGuard.app" ]; then
    echo "🗑️  删除旧版本..."
    rm -rf "$TARGET_DIR/FocusGuard.app"
fi

# 移动应用（使用 mv 而不是 cp）
if [ "$TARGET_DIR" = "/Applications" ]; then
    sudo mv FocusGuard.app "$TARGET_DIR/"
else
    mv FocusGuard.app "$TARGET_DIR/"
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 安装完成!"
    echo ""
    echo "📍 应用位置: $TARGET_DIR/FocusGuard.app"
    echo ""
    echo "🚀 启动方式:"
    if [ "$TARGET_DIR" = "/Applications" ]; then
        echo "   1. 在 Launchpad 中找到 FocusGuard"
        echo "   2. 使用 Spotlight 搜索（Cmd + Space，输入 FocusGuard）"
        echo "   3. 在访达的「应用程序」文件夹中双击"
        echo "   4. 在 Dock 中显示（推荐固定）"
    else
        echo "   1. 使用 Spotlight 搜索（Cmd + Space，输入 FocusGuard）"
        echo "   2. 按 Cmd+Shift+G 打开「前往文件夹」，输入 ~/Applications"
        echo "   3. 在访达的「应用程序」文件夹中双击"
        echo "   4. 添加到 Dock：右键 Dock 图标 → 选项 → 保留在程序坞"
    fi
    echo ""
    echo "⚠️  首次启动可能需要在系统设置中允许："
    echo "   系统设置 → 隐私与安全性 → 摄像头 → 勾选 FocusGuard"
    echo ""
else
    echo "❌ 安装失败"
    exit 1
fi
