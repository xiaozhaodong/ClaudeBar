#!/bin/bash

# ClaudeBar 构建脚本
# Usage: ./build.sh [release|debug]

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="ClaudeBar"
SCHEME_NAME="ClaudeBar"
BUILD_DIR="$PROJECT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

# 默认构建配置
BUILD_CONFIG="Release"
if [ "$1" = "debug" ]; then
    BUILD_CONFIG="Debug"
fi

echo "🚀 开始构建 $PROJECT_NAME ($BUILD_CONFIG)..."

# 清理之前的构建
echo "🧹 清理构建目录..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 切换到项目目录
cd "$PROJECT_DIR"

# 构建项目
echo "🔨 构建项目..."
xcodebuild -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration "$BUILD_CONFIG" \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$ARCHIVE_PATH" \
    archive

if [ $? -ne 0 ]; then
    echo "❌ 构建失败!"
    exit 1
fi

# 导出应用
echo "📦 导出应用..."
cat > "$BUILD_DIR/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string></string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>thinning</key>
    <string>&lt;none&gt;</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist"

if [ $? -ne 0 ]; then
    echo "⚠️  导出失败，尝试直接复制应用..."
    
    # 从归档中直接复制应用
    mkdir -p "$EXPORT_PATH"
    cp -R "$ARCHIVE_PATH/Products/Applications/$PROJECT_NAME.app" "$EXPORT_PATH/"
fi

# 创建 DMG（可选）
if command -v create-dmg &> /dev/null; then
    echo "💿 创建 DMG 文件..."
    create-dmg \
        --volname "$PROJECT_NAME" \
        --volicon "$PROJECT_DIR/$PROJECT_NAME/Assets.xcassets/AppIcon.appiconset" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "$PROJECT_NAME.app" 175 120 \
        --hide-extension "$PROJECT_NAME.app" \
        --app-drop-link 425 120 \
        "$BUILD_DIR/$PROJECT_NAME.dmg" \
        "$EXPORT_PATH"
fi

echo "✅ 构建完成!"
echo "📁 构建产物位置: $EXPORT_PATH"

if [ -f "$EXPORT_PATH/$PROJECT_NAME.app/Contents/MacOS/$PROJECT_NAME" ]; then
    echo "🎯 应用路径: $EXPORT_PATH/$PROJECT_NAME.app"
    echo "📊 应用大小: $(du -sh "$EXPORT_PATH/$PROJECT_NAME.app" | cut -f1)"
fi

echo ""
echo "🔧 安装说明:"
echo "1. 将 $PROJECT_NAME.app 拖拽到 Applications 文件夹"
echo "2. 首次运行时可能需要在系统偏好设置中允许应用运行"
echo "3. 应用将在菜单栏中显示一个终端图标"