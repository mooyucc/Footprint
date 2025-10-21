#!/bin/zsh

# Footprint 项目 - Git初始化脚本
# 使用说明：首次使用时运行此脚本来初始化git仓库

echo "======================================"
echo "  Footprint 项目 - Git初始化"
echo "======================================"
echo ""

# 进入项目目录
cd "$(dirname "$0")"

# 检查是否已经是git仓库
if [ -d ".git" ]; then
    echo "⚠️  已经是git仓库，跳过初始化"
else
    echo "📦 初始化git仓库..."
    git init
    echo "✅ Git仓库初始化完成"
fi

# 添加远程仓库
echo ""
echo "🔗 配置远程仓库..."

# 先检查是否已有origin
if git remote | grep -q "origin"; then
    echo "⚠️  远程仓库origin已存在，移除旧配置..."
    git remote remove origin
fi

git remote add origin https://github.com/mooyucc/Footprint.git
echo "✅ 远程仓库配置完成"

# 创建.gitignore文件（如果不存在）
if [ ! -f ".gitignore" ]; then
    echo ""
    echo "📝 创建.gitignore文件..."
    cat > .gitignore << 'EOF'
# Xcode
#
# gitignore contributors: remember to update Global/Xcode.gitignore, Objective-C.gitignore & Swift.gitignore

## User settings
xcuserdata/

## compatibility with Xcode 8 and earlier (ignoring not required starting Xcode 9)
*.xcscmblueprint
*.xccheckout

## compatibility with Xcode 3 and earlier (ignoring not required starting Xcode 4)
build/
DerivedData/
*.moved-aside
*.pbxuser
!default.pbxuser
*.mode1v3
!default.mode1v3
*.mode2v3
!default.mode2v3
*.perspectivev3
!default.perspectivev3

## Obj-C/Swift specific
*.hmap

## App packaging
*.ipa
*.dSYM.zip
*.dSYM

## Playgrounds
timeline.xctimeline
playground.xcworkspace

# Swift Package Manager
#
# Add this line if you want to avoid checking in source code from Swift Package Manager dependencies.
# Packages/
# Package.pins
# Package.resolved
# *.xcodeproj
#
# Xcode automatically generates this directory with a .xcworkspacedata file and xcuserdata
# hence it is not needed unless you have added a package configuration file to your project
# .swiftpm

.build/

# CocoaPods
#
# We recommend against adding the Pods directory to your .gitignore. However
# you should judge for yourself, the pros and cons are mentioned at:
# https://guides.cocoapods.org/using/using-cocoapods.html#should-i-check-the-pods-directory-into-source-control
#
# Pods/
#
# Add this line if you want to avoid checking in source code from the Xcode workspace
# *.xcworkspace

# Carthage
#
# Add this line if you want to avoid checking in source code from Carthage dependencies.
# Carthage/Checkouts

Carthage/Build/

# Accio dependency management
Dependencies/
.accio/

# fastlane
#
# It is recommended to not store the screenshots in the git repo.
# Instead, use fastlane to re-generate the screenshots whenever they are needed.
# For more information about the recommended setup visit:
# https://docs.fastlane.tools/best-practices/source-control/#source-control

fastlane/report.xml
fastlane/Preview.html
fastlane/screenshots/**/*.png
fastlane/test_output

# Code Injection
#
# After new code Injection tools there's a generated folder /iOSInjectionProject
# https://github.com/johnno1962/injectionforxcode

iOSInjectionProject/

# macOS
.DS_Store
EOF
    echo "✅ .gitignore文件创建完成"
fi

# 检查远程仓库是否有内容
echo ""
echo "🔍 检查远程仓库..."
if git ls-remote origin HEAD > /dev/null 2>&1; then
    echo "⚠️  远程仓库已有内容，建议先拉取远程代码..."
    echo ""
    read "response?是否要拉取远程代码？(y/n): "
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo "📥 拉取远程代码..."
        git fetch origin
        
        # 检查远程有哪些分支
        if git ls-remote --heads origin main > /dev/null 2>&1; then
            echo "发现 main 分支，正在拉取..."
            git branch -M main
            git pull origin main --allow-unrelated-histories
        elif git ls-remote --heads origin master > /dev/null 2>&1; then
            echo "发现 master 分支，正在拉取..."
            git branch -M master
            git pull origin master --allow-unrelated-histories
        fi
        
        if [ $? -eq 0 ]; then
            echo "✅ 远程代码拉取成功"
        else
            echo "⚠️  拉取时可能有冲突，请手动解决"
        fi
    else
        echo "⚠️  跳过拉取，后续推送时可能需要使用 --force"
    fi
else
    echo "✅ 远程仓库为空，可以直接推送"
fi

# 显示当前状态
echo ""
echo "📊 当前仓库状态："
git status

echo ""
echo "======================================"
echo "  ✅ 初始化完成！"
echo "======================================"
echo ""
echo "接下来你可以："
echo "1. 运行 ./upload.sh 来上传代码到GitHub"
echo "2. 或手动使用git命令"
echo ""

