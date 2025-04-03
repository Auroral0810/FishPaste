#!/bin/bash

# 颜色常量
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # 重置颜色

echo "=== 验证 FishCopy 应用图标配置 ==="

# 验证状态变量
ERRORS=0
WARNINGS=0

# 检查 Info.plist 中的 CFBundleIconFile
if grep -q "<key>CFBundleIconFile</key>" "FishCopy/Info.plist"; then
    echo -e "${GREEN}✓ Info.plist 包含 CFBundleIconFile 键${NC}"
else
    echo -e "${RED}✗ Info.plist 缺少 CFBundleIconFile 键${NC}"
    ERRORS=$((ERRORS+1))
fi

# 检查 AppIcon.appiconset 目录
if [ -d "FishCopy/Assets.xcassets/AppIcon.appiconset" ]; then
    echo -e "${GREEN}✓ 找到 AppIcon.appiconset 目录${NC}"
    
    # 检查 Contents.json 文件
    if [ -f "FishCopy/Assets.xcassets/AppIcon.appiconset/Contents.json" ]; then
        echo -e "${GREEN}✓ 找到 AppIcon.appiconset/Contents.json 文件${NC}"
    else
        echo -e "${RED}✗ 缺少 AppIcon.appiconset/Contents.json 文件${NC}"
        ERRORS=$((ERRORS+1))
    fi
    
    # 检查图标文件
    ICON_SIZES=("16x16" "16x16@2x" "32x32" "32x32@2x" "128x128" "128x128@2x" "256x256" "256x256@2x" "512x512" "512x512@2x")
    
    for size in "${ICON_SIZES[@]}"; do
        if [ -f "FishCopy/Assets.xcassets/AppIcon.appiconset/icon_${size}.png" ]; then
            echo -e "${GREEN}✓ 找到图标: icon_${size}.png${NC}"
        else
            echo -e "${RED}✗ 缺少图标: icon_${size}.png${NC}"
            ERRORS=$((ERRORS+1))
        fi
    done
else
    echo -e "${RED}✗ 缺少 AppIcon.appiconset 目录${NC}"
    ERRORS=$((ERRORS+1))
fi

# 检查资源目录中的图标
RESOURCES_ICONS=("appLogo_128x128.png" "appLogo_256x256.png" "appLogo_512x512.png" "statusBarIcon.png" "statusBarIcon@2x.png")
for icon in "${RESOURCES_ICONS[@]}"; do
    if [ -f "FishCopy/Resources/${icon}" ]; then
        echo -e "${GREEN}✓ 找到资源图标: ${icon}${NC}"
    else
        echo -e "${YELLOW}! 资源目录中缺少图标: ${icon}${NC}"
        WARNINGS=$((WARNINGS+1))
    fi
done

# 输出验证结果
echo ""
echo "=== 验证完成 ==="
if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}发现 ${ERRORS} 个错误${NC}"
fi

if [ $WARNINGS -gt 0 ]; then
    echo -e "${YELLOW}发现 ${WARNINGS} 个警告${NC}"
fi

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}所有图标配置正确!${NC}"
fi

exit $ERRORS 