#!/bin/bash

# 确保脚本在错误时停止
set -e

# 检查是否安装了librsvg
if ! command -v rsvg-convert &> /dev/null; then
    echo "需要安装librsvg。请运行: brew install librsvg"
    exit 1
fi

# 设置路径
SVG_PATH="./FishCopy/Resources/appLogo.svg"
OUTPUT_DIR="./FishCopy/Resources"

# 确保目录存在
mkdir -p "$OUTPUT_DIR"

# 生成应用Logo的PNG版本
echo "开始生成应用Logo的PNG版本..."

# 生成不同尺寸的Logo
SIZES=("128" "256" "512")

for size in "${SIZES[@]}"; do
    output_file="${OUTPUT_DIR}/appLogo_${size}x${size}.png"
    rsvg-convert -w "$size" -h "$size" -o "$output_file" "$SVG_PATH"
    echo "生成了 ${size}x${size} 应用Logo"
done

echo "应用Logo生成完成！"
echo "所有图标已保存到: $OUTPUT_DIR" 