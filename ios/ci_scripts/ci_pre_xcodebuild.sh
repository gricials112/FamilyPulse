#!/bin/sh

#  FamilyPulse
#  ci_pre_xcodebuild.sh - Xcode Cloud pre-build script
#
#  自动设置 Info.plist 的 CFBundleVersion，确保 "bundle version must be higher" 不报错。

set -e

echo "ci_pre_xcodebuild.sh - 自动设置构建号..."

if [ -n "$CI_BUILD_NUMBER" ]; then
    # CI_BUILD_NUMBER 开始于 1，设为 CI_BUILD_NUMBER + 99 确保高于历史版本
    NEW_VERSION=$((CI_BUILD_NUMBER + 99))
    echo "CI_BUILD_NUMBER = $CI_BUILD_NUMBER → 构建号 = $NEW_VERSION"

    # 直接修改自定义 Info.plist 中的 CFBundleVersion
    PLIST="${CI_PRIMARY_REPOSITORY_PATH}/ios/Info.plist"
    if [ -f "$PLIST" ]; then
        /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_VERSION" "$PLIST" 2>/dev/null || \
        /usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $NEW_VERSION" "$PLIST"
        echo "Info.plist CFBundleVersion 设为 $NEW_VERSION"
    fi

    # 也更新 pbxproj 保持同步（使用 agvtool，比 sed 安全）
    cd "${CI_PRIMARY_REPOSITORY_PATH}/ios"
    agvtool new-version -all "$NEW_VERSION" >/dev/null 2>&1 || true

    echo "构建号 $NEW_VERSION 设置完成"
else
    echo "不在 Xcode Cloud 环境，跳过自动设置构建号"
fi
