#!/bin/zsh

# GitHub认证配置脚本
# 此脚本会安全地配置GitHub Personal Access Token

echo "======================================"
echo "  配置GitHub认证"
echo "======================================"
echo ""

# 进入项目目录
cd "$(dirname "$0")"

# 配置Git使用macOS Keychain存储凭据
echo "🔐 配置Git credential helper..."
git config --global credential.helper osxkeychain

# 配置用户信息（如果还没有配置）
CURRENT_USER=$(git config --global user.name)
CURRENT_EMAIL=$(git config --global user.email)

if [ -z "$CURRENT_USER" ]; then
    echo ""
    echo "📝 请输入你的GitHub用户名："
    read "github_username?用户名: "
    git config --global user.name "$github_username"
    echo "✅ 用户名已配置: $github_username"
fi

if [ -z "$CURRENT_EMAIL" ]; then
    echo ""
    echo "📧 请输入你的GitHub邮箱："
    read "github_email?邮箱: "
    git config --global user.email "$github_email"
    echo "✅ 邮箱已配置: $github_email"
fi

echo ""
echo "======================================"
echo "  ✅ 认证配置完成！"
echo "======================================"
echo ""
echo "当前Git配置："
echo "用户名: $(git config --global user.name)"
echo "邮箱: $(git config --global user.email)"
echo ""
echo "📝 下次推送时："
echo "- 用户名输入: $(git config --global user.name) 或 mooyucc"
echo "- 密码输入: 你的Personal Access Token"
echo "- macOS会自动保存到Keychain，以后无需再次输入"
echo ""

