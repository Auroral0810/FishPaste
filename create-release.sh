#!/bin/bash

# FishCopy 本地发布辅助脚本
# 此脚本帮助您创建新版本标签并推送到GitHub，触发自动构建和发布流程

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 恢复颜色

# 检查Git是否可用
if ! command -v git &> /dev/null; then
    echo -e "${RED}错误: 未找到Git命令${NC}"
    echo "请安装Git后再运行此脚本"
    exit 1
fi

# 检查当前目录是否为Git仓库
if [ ! -d .git ]; then
    echo -e "${RED}错误: 当前目录不是Git仓库${NC}"
    echo "请在FishCopy项目的根目录运行此脚本"
    exit 1
fi

# 显示当前分支和最新提交
echo -e "${BLUE}当前Git状态:${NC}"
git status -s
echo ""
echo -e "${BLUE}最近的提交:${NC}"
git log -3 --oneline
echo ""

# 检查未提交的更改
if [ -n "$(git status --porcelain)" ]; then
    echo -e "${YELLOW}警告: 存在未提交的更改${NC}"
    echo "建议在创建发布标签前提交所有更改"
    
    read -p "是否继续? (y/n): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# 获取最新标签
latest_tag=$(git describe --tags --abbrev=0 2>/dev/null)
if [ -z "$latest_tag" ]; then
    echo -e "${YELLOW}未找到现有标签，将使用v1.0.0作为建议版本${NC}"
    suggested_version="v1.0.0"
else
    echo -e "${BLUE}最新标签:${NC} $latest_tag"
    
    # 提取版本号并建议新版本
    # 假设标签格式为v1.2.3
    if [[ $latest_tag =~ v([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
        major=${BASH_REMATCH[1]}
        minor=${BASH_REMATCH[2]}
        patch=${BASH_REMATCH[3]}
        
        # 增加补丁版本号
        patch=$((patch + 1))
        suggested_version="v$major.$minor.$patch"
    else
        # 如果标签格式不匹配，建议使用v1.0.0
        suggested_version="v1.0.0"
    fi
fi

# 询问用户新版本号
echo -e "${BLUE}请输入新版本号${NC} (建议: $suggested_version):"
read -p "> " version
if [ -z "$version" ]; then
    version=$suggested_version
fi

# 确保版本号以v开头
if [[ ! $version == v* ]]; then
    version="v$version"
    echo -e "${YELLOW}已添加'v'前缀: $version${NC}"
fi

# 确认创建标签
echo -e "${BLUE}将创建标签:${NC} $version"
read -p "确认? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}已取消${NC}"
    exit 0
fi

# 创建标签
echo -e "${BLUE}创建标签 $version...${NC}"
git tag $version

# 询问是否推送标签
echo -e "${BLUE}标签已创建。是否推送到远程仓库?${NC}"
echo "推送后将触发GitHub Actions自动构建和发布流程"
read -p "推送标签? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}推送标签...${NC}"
    git push origin $version
    
    echo -e "${GREEN}标签 $version 已成功推送${NC}"
    echo "GitHub Actions将开始自动构建和发布流程"
    echo "您可以在GitHub仓库的Actions标签页查看进度"
    echo "https://github.com/YOUR_USERNAME/FishCopy/actions"
else
    echo -e "${YELLOW}标签仅在本地创建，未推送到远程仓库${NC}"
    echo "稍后可使用以下命令推送:"
    echo "  git push origin $version"
fi

echo -e "${GREEN}完成!${NC}" 