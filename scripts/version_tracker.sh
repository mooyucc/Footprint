#!/bin/bash

# Footprint 版本记录脚本
# 自动记录每次Archive的版本信息

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目路径
PROJECT_DIR="/Users/kevinx/Documents/Ai Project/Footprint"
PROJECT_FILE="$PROJECT_DIR/Footprint.xcodeproj/project.pbxproj"
VERSION_LOG="$PROJECT_DIR/版本记录.md"
TEMP_FILE="/tmp/footprint_version_temp.md"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查项目文件是否存在
check_project_file() {
    if [ ! -f "$PROJECT_FILE" ]; then
        log_error "项目文件不存在: $PROJECT_FILE"
        exit 1
    fi
}

# 自动递增Build数字
auto_increment_build() {
    log_info "正在自动递增Build数字..."
    
    # 获取当前Build数字
    CURRENT_BUILD=$(grep -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PROJECT_FILE" | head -1 | sed 's/CURRENT_PROJECT_VERSION = //')
    NEW_BUILD=$((CURRENT_BUILD + 1))
    
    log_info "当前Build数字: $CURRENT_BUILD"
    log_info "新Build数字: $NEW_BUILD"
    
    # 备份原文件
    cp "$PROJECT_FILE" "$PROJECT_FILE.backup"
    
    # 替换所有CURRENT_PROJECT_VERSION
    sed -i.tmp "s/CURRENT_PROJECT_VERSION = [0-9]*/CURRENT_PROJECT_VERSION = $NEW_BUILD/g" "$PROJECT_FILE"
    
    # 清理临时文件
    rm -f "$PROJECT_FILE.tmp"
    
    log_success "Build数字已从 $CURRENT_BUILD 更新为 $NEW_BUILD"
}

# 从Xcode项目文件提取版本信息
extract_version_info() {
    log_info "正在提取版本信息..."
    
    # 自动递增Build数字
    auto_increment_build
    
    # 提取营销版本号
    MARKETING_VERSION=$(grep -o 'MARKETING_VERSION = [^;]*' "$PROJECT_FILE" | head -1 | sed 's/MARKETING_VERSION = //')
    
    # 提取构建版本号（使用递增后的数字）
    CURRENT_PROJECT_VERSION=$(grep -o 'CURRENT_PROJECT_VERSION = [^;]*' "$PROJECT_FILE" | head -1 | sed 's/CURRENT_PROJECT_VERSION = //')
    
    # 获取当前日期
    CURRENT_DATE=$(date '+%Y-%m-%d')
    
    # 获取当前时间
    CURRENT_TIME=$(date '+%H:%M:%S')
    
    log_success "版本信息提取完成"
    log_info "营销版本: $MARKETING_VERSION"
    log_info "构建版本: $CURRENT_PROJECT_VERSION"
    log_info "日期: $CURRENT_DATE"
}

# 检查版本是否已存在
check_version_exists() {
    if grep -q "\[Version $MARKETING_VERSION\]" "$VERSION_LOG"; then
        log_warning "版本 $MARKETING_VERSION 已存在，将更新现有记录"
        return 0
    else
        log_info "新版本 $MARKETING_VERSION，将创建新记录"
        return 1
    fi
}

# 创建新版本记录
create_new_version_record() {
    log_info "创建新版本记录..."
    
    # 创建临时文件，在版本历史部分插入新记录
    {
        # 写入文件头部
        head -n 3 "$VERSION_LOG"
        echo ""
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
        
        # 写入其余内容（跳过前3行和第一个版本记录）
        tail -n +4 "$VERSION_LOG" | sed '/^## 版本历史$/,$d'
        
        # 写入版本历史部分
        echo "## 版本历史"
        echo ""
        tail -n +4 "$VERSION_LOG" | sed -n '/^## 版本历史$/,$p'
        
    } > "$TEMP_FILE"
    
    # 替换原文件
    mv "$TEMP_FILE" "$VERSION_LOG"
    
    log_success "新版本记录已创建"
}

# 更新现有版本记录
update_existing_version_record() {
    log_info "更新现有版本记录..."
    
    # 更新构建版本和日期
    sed -i.bak "s/\*\*构建版本\*\*: [0-9]*/\*\*构建版本\*\*: $CURRENT_PROJECT_VERSION/g" "$VERSION_LOG"
    sed -i.bak "s/\*\*发布日期\*\*: [0-9-]*/\*\*发布日期\*\*: $CURRENT_DATE/g" "$VERSION_LOG"
    
    # 添加更新时间
    if ! grep -q "\*\*更新时间\*\*:" "$VERSION_LOG"; then
        sed -i.bak "/\*\*发布日期\*\*: $CURRENT_DATE/a\\
**更新时间**: $CURRENT_TIME  " "$VERSION_LOG"
    else
        sed -i.bak "s/\*\*更新时间\*\*: [0-9:]*/\*\*更新时间\*\*: $CURRENT_TIME/g" "$VERSION_LOG"
    fi
    
    # 清理备份文件
    rm -f "$VERSION_LOG.bak"
    
    log_success "现有版本记录已更新"
}

# 打开编辑器让用户编辑更新内容
edit_version_content() {
    log_info "请编辑版本更新内容..."
    log_warning "按 Ctrl+X 然后 Y 保存并退出编辑器"
    
    # 使用nano编辑器（如果可用）
    if command -v nano >/dev/null 2>&1; then
        nano "$VERSION_LOG"
    elif command -v vim >/dev/null 2>&1; then
        vim "$VERSION_LOG"
    else
        log_warning "未找到文本编辑器，请手动编辑: $VERSION_LOG"
    fi
}

# 提交到Git（如果存在）
commit_to_git() {
    if [ -d "$PROJECT_DIR/.git" ]; then
        log_info "提交版本记录到Git..."
        cd "$PROJECT_DIR"
        git add "$VERSION_LOG"
        git commit -m "📝 更新版本记录 - v$MARKETING_VERSION ($CURRENT_PROJECT_VERSION)"
        log_success "版本记录已提交到Git"
    else
        log_warning "未检测到Git仓库，跳过提交"
    fi
}

# 显示版本记录摘要
show_version_summary() {
    log_success "版本记录更新完成！"
    echo ""
    echo "📋 版本信息摘要:"
    echo "   版本号: $MARKETING_VERSION"
    echo "   构建号: $CURRENT_PROJECT_VERSION"
    echo "   日期: $CURRENT_DATE $CURRENT_TIME"
    echo "   记录文件: $VERSION_LOG"
    echo ""
    echo "📝 下一步操作:"
    echo "   1. 编辑版本记录文件添加更新内容"
    echo "   2. 在Xcode中Archive项目"
    echo "   3. 提交更改到Git仓库"
    echo ""
}

# 主函数
main() {
    log_info "🚀 开始版本记录流程..."
    
    # 检查项目文件
    check_project_file
    
    # 提取版本信息
    extract_version_info
    
    # 检查版本是否已存在
    if check_version_exists; then
        update_existing_version_record
    else
        create_new_version_record
    fi
    
    # 显示摘要
    show_version_summary
    
    # 询问是否编辑内容
    read -p "是否现在编辑版本更新内容？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        edit_version_content
    fi
    
    # 询问是否提交到Git
    read -p "是否提交到Git仓库？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        commit_to_git
    fi
    
    log_success "✅ 版本记录流程完成！"
}

# 运行主函数
main "$@"
