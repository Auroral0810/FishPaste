#!/bin/bash

# 确保脚本在错误时停止
set -e

# 检查是否安装了librsvg
if ! command -v rsvg-convert &> /dev/null; then
    echo "需要安装librsvg。请运行: brew install librsvg"
    exit 1
fi

# 设置路径
SVG_PATH="./FishCopy/Resources/statusBarIcon.svg"
OUTPUT_DIR="./FishCopy/Resources"

# 确保目录存在
mkdir -p "$OUTPUT_DIR"

# 生成不同尺寸的状态栏图标
echo "开始生成状态栏图标..."

# 状态栏图标尺寸 - 标准和2x分辨率
SIZES=("18" "36")

for size in "${SIZES[@]}"; do
    output_file=""
    if [ "$size" == "18" ]; then
        output_file="${OUTPUT_DIR}/statusBarIcon.png"
        echo "生成标准尺寸状态栏图标 (${size}x${size})"
    else
        output_file="${OUTPUT_DIR}/statusBarIcon@2x.png"
        echo "生成Retina尺寸状态栏图标 (${size}x${size})"
    fi
    
    rsvg-convert -w "$size" -h "$size" -o "$output_file" "$SVG_PATH"
done

echo "状态栏图标生成完成！"
echo "图标已保存到: $OUTPUT_DIR" 