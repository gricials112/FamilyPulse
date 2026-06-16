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

    # 使用 agvtool 更新项目中的所有 target 的 CURRENT_PROJECT_VERSION
    # 这比 sed 改 pbxproj 更安全，agvtool 会正确处理所有 target
    cd "$CI_PRIMARY_REPOSITORY_PATH/ios"
    agvtool new-version -all "$CI_BUILD_NUMBER"

    echo "构建号已设为 $CI_BUILD_NUMBER"
else
    echo "不在 Xcode Cloud 环境，跳过自动设置构建号"
fi
