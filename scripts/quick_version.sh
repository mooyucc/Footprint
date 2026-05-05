#!/bin/bash

# 快速版本记录脚本
# 用于Archive后快速记录版本信息

PROJECT_DIR="/Users/kevinx/Documents/Ai Project/Footprint"
PROJECT_FILE="$PROJECT_DIR/Footprint.xcodeproj/project.pbxproj"
VERSION_CONFIG="$PROJECT_DIR/Configs/Version.xcconfig"
VERSION_LOG="$PROJECT_DIR/版本记录.md"

# 提取版本信息
if [ -f "$VERSION_CONFIG" ]; then
    MARKETING_VERSION=$(grep -m1 '^MARKETING_VERSION' "$VERSION_CONFIG" | sed 's/MARKETING_VERSION = //' | tr -d ' ')
else
    MARKETING_VERSION=$(grep -o 'MARKETING_VERSION = [^;]*' "$PROJECT_FILE" | head -1 | sed 's/MARKETING_VERSION = //')
fi
CURRENT_PROJECT_VERSION=$(grep -o 'CURRENT_PROJECT_VERSION = [^;]*' "$PROJECT_FILE" | head -1 | sed 's/CURRENT_PROJECT_VERSION = //')
CURRENT_DATE=$(date '+%Y-%m-%d')
CURRENT_TIME=$(date '+%H:%M:%S')

# 创建新版本记录
{
    echo "### [Version $MARKETING_VERSION] - $CURRENT_DATE"
    echo "**构建版本**: $CURRENT_PROJECT_VERSION  "
    echo "**发布日期**: $CURRENT_DATE  "
    echo "**更新时间**: $CURRENT_TIME  "
    echo "**更新类型**: 功能更新"
    echo ""
    echo "#### 🎯 主要更新"
    echo "- 请在此处添加主要功能更新"
    echo ""
    echo "#### 🔧 技术改进"
    echo "- 请在此处添加技术改进说明"
    echo ""
    echo "#### 📱 用户体验"
    echo "- 请在此处添加用户体验改进"
    echo ""
    echo "---"
    echo ""
} > /tmp/new_version.md

# 将新版本记录插入到版本历史部分
{
    # 写入文件头部
    head -n 3 "$VERSION_LOG"
    echo ""
    cat /tmp/new_version.md
    
    # 写入版本历史部分
    echo "## 版本历史"
    echo ""
    tail -n +4 "$VERSION_LOG" | sed -n '/^## 版本历史$/,$p'
    
} > /tmp/version_log_updated.md

# 替换原文件
mv /tmp/version_log_updated.md "$VERSION_LOG"
rm -f /tmp/new_version.md

echo "✅ 版本记录已更新: v$MARKETING_VERSION ($CURRENT_PROJECT_VERSION)"
echo "📝 请编辑 版本记录.md 添加具体更新内容"
