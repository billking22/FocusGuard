#!/bin/bash

echo "📦 FocusGuard .app 构建脚本"
echo "=============================="
echo ""

# 配置变量
APP_NAME="FocusGuard"
BUILD_MODE="${1:-release}"  # 默认使用 release 模式
BUILD_DIR=".build/arm64-apple-macosx/${BUILD_MODE}"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# 检查参数
if [ "$BUILD_MODE" != "debug" ] && [ "$BUILD_MODE" != "release" ]; then
    echo "❌ 错误: 构建模式必须是 'debug' 或 'release'"
    echo "   用法: ./build-app.sh [debug|release]"
    exit 1
fi

# 清理旧的构建
if [ -d "${APP_BUNDLE}" ]; then
    echo "🧹 清理旧的构建..."
    rm -rf "${APP_BUNDLE}"
fi

# 编译项目
echo "🔨 开始编译 (${BUILD_MODE} 模式)..."
swift build -c "${BUILD_MODE}"

if [ $? -ne 0 ]; then
    echo "❌ 编译失败"
    exit 1
fi

echo "✅ 编译成功!"
echo ""

# 创建 .app 包结构
echo "📁 创建应用包结构..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# 复制可执行文件
echo "📝 复制可执行文件..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# 复制 Info.plist
echo "📋 复制 Info.plist..."
cp "Resources/Info.plist" "${CONTENTS_DIR}/"

# 设置图标（如果存在）
if [ -f "Resources/AppIcon.icns" ]; then
    echo "🎨 添加应用图标..."
    cp "Resources/AppIcon.icns" "${RESOURCES_DIR}/"
    # 更新 Info.plist 中的图标路径
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon.icns" "${CONTENTS_DIR}/Info.plist" 2>/dev/null || true
fi

echo ""
echo "✅ 应用包构建完成: ${APP_BUNDLE}"
echo ""
echo "📦 安装方式:"
echo "   1. 双击 ${APP_BUNDLE} 运行"
echo "   2. 拖拽 ${APP_BUNDLE} 到 /Applications 文件夹安装"
echo "   3. 添加到 Dock: 右键 → 选项 → 保留在程序坞"
echo ""
echo "⚠️  注意事项:"
echo "   - 首次运行可能需要在「系统设置 → 隐私与安全性」中允许"
echo "   - 需要授予摄像头权限"
echo "   - 如果应用无法启动，尝试删除 ~/Library/Preferences/com.focusguard.app.plist"
echo ""
