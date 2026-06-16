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
echo "ci_pre_xcodebuild.sh - 使用项目当前构建号"
echo "CI_WORKFLOW = ${CI_WORKFLOW:-N/A}"
echo "当前构建号已在 project.pbxproj 中设置"
