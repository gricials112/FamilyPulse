#!/bin/sh

#  FamilyPulse
#  ci_pre_xcodebuild.sh - Xcode Cloud pre-build script
#
#  自动递增构建号，避免 "bundle version must be higher" 错误。
#  Xcode Cloud 提供 $CI_BUILD_NUMBER 环境变量（每次构建递增）。
#  本地构建也可通过 agvtool 手动管理。

set -e

echo "ci_pre_xcodebuild.sh - 自动设置构建号..."

# Xcode Cloud 环境变量
if [ -n "$CI_BUILD_NUMBER" ]; then
    echo "CI_BUILD_NUMBER = $CI_BUILD_NUMBER"

    cd "$CI_PRIMARY_REPOSITORY_PATH/ios"

    # 读取当前项目中的构建号作为基准
    CURRENT_VERSION=$(agvtool what-version -terse 2>/dev/null || echo "0")
    echo "项目当前构建号 = $CURRENT_VERSION"

    # 新构建号 = max(当前项目版本, CI_BUILD_NUMBER + 9)
    # 9 是历史最大构建号的偏移，确保每次 CI 构建都递增
    OFFSET=9
    NEW_VERSION=$((CI_BUILD_NUMBER + OFFSET))
    if [ "$NEW_VERSION" -lt "$CURRENT_VERSION" ]; then
        NEW_VERSION=$CURRENT_VERSION
    fi

    agvtool new-version -all "$NEW_VERSION"
    echo "构建号已设为 $NEW_VERSION"
else
    echo "不在 Xcode Cloud 环境，跳过自动设置构建号"
fi
