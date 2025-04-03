#!/bin/bash

# 确保脚本在错误时停止
set -e

# 检查是否安装了librsvg（包含rsvg-convert工具）
if ! command -v rsvg-convert &> /dev/null; then
    echo "需要安装librsvg。请运行: brew install librsvg"
    exit 1
fi

# 设置路径
SVG_PATH="./FishCopy/Resources/logo.svg"
ICON_SET_PATH="./FishCopy/Assets.xcassets/AppIcon.appiconset"

# 确保目录存在
mkdir -p "$ICON_SET_PATH"

# 转换不同尺寸的图标
echo "开始生成各种尺寸的图标..."

# macOS图标尺寸
SIZES=("16" "32" "64" "128" "256" "512" "1024")

for size in "${SIZES[@]}"; do
    if [ "$size" == "64" ]; then
        # 64x64仅用于32x32@2x
        rsvg-convert -w "$size" -h "$size" -o "${ICON_SET_PATH}/icon_32x32@2x.png" "$SVG_PATH"
        echo "生成了 ${size}x${size} 图标 (用于32x32@2x)"
    elif [ "$size" == "1024" ]; then
        # 1024x1024用于512x512@2x
        rsvg-convert -w "$size" -h "$size" -o "${ICON_SET_PATH}/icon_512x512@2x.png" "$SVG_PATH"
        echo "生成了 ${size}x${size} 图标 (用于512x512@2x)"
    else
        # 普通尺寸
        rsvg-convert -w "$size" -h "$size" -o "${ICON_SET_PATH}/icon_${size}x${size}.png" "$SVG_PATH"
        echo "生成了 ${size}x${size} 图标"
        
        # 2x尺寸(除了已处理的情况)
        if [ "$size" == "16" ] || [ "$size" == "128" ] || [ "$size" == "256" ]; then
            double=$((size * 2))
            rsvg-convert -w "$double" -h "$double" -o "${ICON_SET_PATH}/icon_${size}x${size}@2x.png" "$SVG_PATH"
            echo "生成了 ${size}x${size}@2x 图标 (${double}x${double})"
        fi
    fi
done

echo "图标生成完成！"
echo "所有图标已保存到: $ICON_SET_PATH" 