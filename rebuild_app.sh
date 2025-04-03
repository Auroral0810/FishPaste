#!/bin/bash

# 确保脚本在错误时停止
set -e

echo "=== 开始重新构建 FishCopy 应用 ==="

# 1. 清理DerivedData
echo "清理DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*FishCopy*

# 2. 清理构建
echo "清理构建..."
xcodebuild clean -project FishCopy.xcodeproj -scheme FishCopy

# 3. 构建应用
echo "构建应用..."
xcodebuild -project FishCopy.xcodeproj -scheme FishCopy -configuration Debug build

echo "=== 构建完成！ ==="
echo "您可以在Xcode中运行应用，或者在以下位置找到构建的应用："
echo "~/Library/Developer/Xcode/DerivedData/FishCopy-*/Build/Products/Debug/FishCopy.app"

# 尝试查找构建后的应用位置
BUILD_DIR=$(find ~/Library/Developer/Xcode/DerivedData -name "FishCopy-*" -type d -depth 1 2>/dev/null | head -n 1)
if [ -n "$BUILD_DIR" ]; then
    APP_PATH="$BUILD_DIR/Build/Products/Debug/FishCopy.app"
    if [ -d "$APP_PATH" ]; then
        echo "应用已构建在: $APP_PATH"
        echo "您可以运行以下命令来启动应用:"
        echo "open \"$APP_PATH\""
    fi
fi 