#!/bin/bash

# Xcode构建脚本 - 在Archive时自动运行版本记录
# 此脚本将在Xcode的Build Phases中调用

# 设置项目路径
PROJECT_DIR="${SRCROOT}"
SCRIPT_DIR="${PROJECT_DIR}/scripts"
VERSION_LOG="${PROJECT_DIR}/版本记录.md"

# 检查是否在Archive构建中
if [ "${CONFIGURATION}" = "Release" ] && [ "${EFFECTIVE_PLATFORM_NAME}" != "iphonesimulator" ]; then
    echo "📝 检测到Release构建，开始版本记录..."
    
    # 运行快速版本记录脚本
    if [ -f "${SCRIPT_DIR}/quick_version.sh" ]; then
        bash "${SCRIPT_DIR}/quick_version.sh"
        echo "✅ 版本记录完成"
    else
        echo "⚠️ 版本记录脚本未找到"
    fi
else
    echo "ℹ️ 跳过版本记录 (Debug构建或模拟器)"
fi
