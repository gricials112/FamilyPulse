#!/bin/sh

#  FamilyPulse
#  ci_pre_xcodebuild.sh - Xcode Cloud pre-build script
#
#  自动设置构建号，确保 "bundle version must be higher" 不报错。
#  直接 sed 修改 project.pbxproj 中的 CURRENT_PROJECT_VERSION。

set -e

echo "ci_pre_xcodebuild.sh - 自动设置构建号..."

PBXPROJ="${CI_PRIMARY_REPOSITORY_PATH}/ios/FamilyPulse.xcodeproj/project.pbxproj"

if [ -n "$CI_BUILD_NUMBER" ]; then
    # CI_BUILD_NUMBER 开始于 1，加上 99 的偏移确保始终高于历史构建
    NEW_VERSION=$((CI_BUILD_NUMBER + 99))
    echo "CI_BUILD_NUMBER = $CI_BUILD_NUMBER → 设置构建号 = $NEW_VERSION"

    # 直接 sed 修改 pbxproj 中的所有 CURRENT_PROJECT_VERSION
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $NEW_VERSION;/g" "$PBXPROJ"

    echo "构建号已设为 $NEW_VERSION"
else
    echo "不在 Xcode Cloud 环境，使用项目当前构建号"
fi
