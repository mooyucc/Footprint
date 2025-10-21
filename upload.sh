#!/bin/zsh

# Footprint 项目 - 自动上传到GitHub脚本
# 使用说明：运行此脚本自动提交并推送代码到GitHub
# 用法: ./upload.sh "提交信息"
# 示例: ./upload.sh "更新功能"

echo "======================================"
echo "  Footprint 项目 - 上传到GitHub"
echo "======================================"
echo ""

# 进入项目目录
cd "$(dirname "$0")"

# 检查是否是git仓库
if [ ! -d ".git" ]; then
    echo "❌ 错误：不是git仓库"
    echo "请先运行 ./init_git.sh 来初始化仓库"
    exit 1
fi

# 检查是否有远程仓库
if ! git remote | grep -q "origin"; then
    echo "❌ 错误：未配置远程仓库"
    echo "请先运行 ./init_git.sh 来配置远程仓库"
    exit 1
fi

# 获取提交信息
COMMIT_MESSAGE="$1"
if [ -z "$COMMIT_MESSAGE" ]; then
    # 如果没有提供提交信息，使用默认信息
    COMMIT_MESSAGE="更新代码 - $(date '+%Y-%m-%d %H:%M:%S')"
fi

echo "📝 提交信息: $COMMIT_MESSAGE"
echo ""

# 显示当前状态
echo "📊 检查当前状态..."
git status
echo ""

# 添加所有更改
echo "➕ 添加所有更改..."
git add .

# 检查是否有更改需要提交
if git diff --cached --quiet; then
    echo "⚠️  没有需要提交的更改"
    echo ""
    echo "======================================"
    echo "  完成 - 无需上传"
    echo "======================================"
    exit 0
fi

# 提交更改
echo "💾 提交更改..."
git commit -m "$COMMIT_MESSAGE"

if [ $? -ne 0 ]; then
    echo "❌ 提交失败"
    exit 1
fi

echo "✅ 提交成功"
echo ""

# 推送到GitHub
echo "🚀 推送到GitHub..."
echo ""

# 检查是否是首次推送
if ! git rev-parse --abbrev-ref --symbolic-full-name @{u} > /dev/null 2>&1; then
    echo "📤 首次推送，设置上游分支..."
    git push -u origin main
    
    # 如果main分支推送失败，尝试master分支
    if [ $? -ne 0 ]; then
        echo "⚠️  main分支推送失败，尝试master分支..."
        # 检查当前分支
        CURRENT_BRANCH=$(git branch --show-current)
        if [ "$CURRENT_BRANCH" != "master" ]; then
            git branch -M master
        fi
        git push -u origin master
    fi
else
    # 正常推送
    git push
fi

if [ $? -eq 0 ]; then
    echo ""
    echo "======================================"
    echo "  ✅ 上传成功！"
    echo "======================================"
    echo ""
    echo "代码已成功推送到："
    echo "https://github.com/mooyucc/Footprint"
    echo ""
else
    echo ""
    echo "======================================"
    echo "  ❌ 推送失败"
    echo "======================================"
    echo ""
    echo "可能的原因："
    echo "1. 网络连接问题"
    echo "2. 没有推送权限（需要配置GitHub认证）"
    echo "3. 远程仓库有冲突"
    echo ""
    echo "建议："
    echo "1. 检查网络连接"
    echo "2. 确保已配置GitHub认证（SSH密钥或Personal Access Token）"
    echo "3. 尝试先拉取远程更改：git pull origin main --rebase"
    echo ""
    exit 1
fi

