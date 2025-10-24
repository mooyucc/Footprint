#!/bin/bash

# 自动递增Build数字脚本
# 在Archive之前运行此脚本

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

# 检查项目文件
if [ ! -f "$PROJECT_FILE" ]; then
    log_error "项目文件不存在: $PROJECT_FILE"
    exit 1
fi

# 获取当前Build数字
get_current_build() {
    CURRENT_BUILD=$(grep -o 'CURRENT_PROJECT_VERSION = [0-9]*' "$PROJECT_FILE" | head -1 | sed 's/CURRENT_PROJECT_VERSION = //')
    echo "$CURRENT_BUILD"
}

# 递增Build数字
increment_build() {
    CURRENT_BUILD=$(get_current_build)
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

# 验证更新
verify_update() {
    NEW_BUILD=$(get_current_build)
    log_info "验证更新结果: Build数字现在是 $NEW_BUILD"
}

# 主函数
main() {
    log_info "🚀 开始自动递增Build数字..."
    
    # 显示当前状态
    CURRENT_BUILD=$(get_current_build)
    log_info "当前Build数字: $CURRENT_BUILD"
    
    # 询问是否继续
    read -p "是否将Build数字从 $CURRENT_BUILD 递增到 $((CURRENT_BUILD + 1))？(y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        increment_build
        verify_update
        log_success "✅ Build数字递增完成！"
        log_info "现在可以在Xcode中Archive项目了"
    else
        log_info "操作已取消"
    fi
}

# 运行主函数
main "$@"
