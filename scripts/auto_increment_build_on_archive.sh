#!/bin/bash

# 自动递增 Build 号脚本
# 在 Archive 时自动运行，递增正式版和测试版的 Build 号

# 使用 set -u 但允许命令失败（不中断构建）
set -u

# 调试信息：输出环境变量
echo "🔍 [Auto Increment Build] 调试信息:"
echo "   ACTION: ${ACTION:-未设置}"
echo "   CONFIGURATION: ${CONFIGURATION:-未设置}"
echo "   PRODUCT_BUNDLE_IDENTIFIER: ${PRODUCT_BUNDLE_IDENTIFIER:-未设置}"
echo "   SRCROOT: ${SRCROOT:-未设置}"

# 只在 Archive 时运行
# 检查是否在 Archive 构建中
# ACTION 在 Archive 时应该是 "install"
# 或者检查 EFFECTIVE_PLATFORM_NAME 不是模拟器
if [[ -n "${ACTION:-}" ]] && [[ "${ACTION}" != "install" ]]; then
    echo "ℹ️  跳过 Build 号递增 (ACTION=${ACTION}, 不是 Archive)"
    exit 0
fi

# 额外检查：如果是模拟器构建，也跳过
if [[ "${EFFECTIVE_PLATFORM_NAME:-}" == "iphonesimulator" ]]; then
    echo "ℹ️  跳过 Build 号递增 (模拟器构建)"
    exit 0
fi

# 项目路径
PROJECT_DIR="${SRCROOT}"
PROJECT_FILE="${PROJECT_DIR}/Footprint.xcodeproj/project.pbxproj"
CONFIG_FILE=""

# 根据配置选择对应的 xcconfig 文件
if [[ "${CONFIGURATION:-}" == "Beta" ]]; then
    CONFIG_FILE="${PROJECT_DIR}/Configs/Beta.xcconfig"
    echo "📦 检测到 Beta 配置，更新测试版 Build 号..."
elif [[ "${CONFIGURATION:-}" == "Release" ]]; then
    CONFIG_FILE="${PROJECT_DIR}/Configs/Prod.xcconfig"
    echo "📦 检测到 Release 配置，更新正式版 Build 号..."
else
    echo "ℹ️  跳过 Build 号递增 (非 Archive 配置: ${CONFIGURATION:-})"
    exit 0
fi

# 检查配置文件是否存在
if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "⚠️  配置文件不存在: ${CONFIG_FILE}"
    exit 0
fi

# 获取当前 Build 号
echo "📖 正在读取配置文件: ${CONFIG_FILE}"
CURRENT_BUILD=$(grep -E "^CURRENT_PROJECT_VERSION\s*=" "${CONFIG_FILE}" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/' | tr -d ' ' || echo "")

if [[ -z "${CURRENT_BUILD}" ]]; then
    echo "⚠️  无法读取当前 Build 号，跳过自动递增"
    echo "   尝试读取的内容: $(grep -E "^CURRENT_PROJECT_VERSION" "${CONFIG_FILE}" || echo '未找到')"
    exit 0
fi

echo "📊 当前 Build 号: ${CURRENT_BUILD}"

# 递增 Build 号
NEW_BUILD=$((CURRENT_BUILD + 1))
echo "📈 新 Build 号: ${NEW_BUILD}"

# 更新配置文件（即使失败也不中断构建）
if [[ "$(uname)" == "Darwin" ]]; then
    # macOS
    echo "💾 正在更新配置文件..."
    if sed -i '' "s/^CURRENT_PROJECT_VERSION\s*=.*/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/" "${CONFIG_FILE}" 2>&1; then
        # 验证更新是否成功
        VERIFIED_BUILD=$(grep -E "^CURRENT_PROJECT_VERSION\s*=" "${CONFIG_FILE}" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/' | tr -d ' ')
        if [[ "${VERIFIED_BUILD}" == "${NEW_BUILD}" ]]; then
            echo "✅ Build 号已从 ${CURRENT_BUILD} 更新为 ${NEW_BUILD} (${CONFIGURATION})"
        else
            echo "⚠️  更新后验证失败 (期望: ${NEW_BUILD}, 实际: ${VERIFIED_BUILD})"
        fi
    else
        echo "⚠️  更新 Build 号失败，但继续构建"
    fi
else
    # Linux
    echo "💾 正在更新配置文件..."
    if sed -i "s/^CURRENT_PROJECT_VERSION\s*=.*/CURRENT_PROJECT_VERSION = ${NEW_BUILD}/" "${CONFIG_FILE}" 2>&1; then
        # 验证更新是否成功
        VERIFIED_BUILD=$(grep -E "^CURRENT_PROJECT_VERSION\s*=" "${CONFIG_FILE}" | head -1 | sed -E 's/.*=\s*([0-9]+).*/\1/' | tr -d ' ')
        if [[ "${VERIFIED_BUILD}" == "${NEW_BUILD}" ]]; then
            echo "✅ Build 号已从 ${CURRENT_BUILD} 更新为 ${NEW_BUILD} (${CONFIGURATION})"
        else
            echo "⚠️  更新后验证失败 (期望: ${NEW_BUILD}, 实际: ${VERIFIED_BUILD})"
        fi
    else
        echo "⚠️  更新 Build 号失败，但继续构建"
    fi
fi

