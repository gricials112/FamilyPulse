#!/bin/bash
set -euo pipefail

cd "$(dirname "$(realpath "$0")")/.."
PROJECT_DIR="$(pwd)"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
FAILED=0

echo "============================================"
echo "  家安 Pre-Commit Hook"
echo "  项目: $PROJECT_DIR"
echo "  运行测试 + 覆盖率检查"
echo "============================================"

# ===============================================
# 1. 后端测试 (Go + coverage >= 90%)
# ===============================================
echo ""
echo -e "${YELLOW}[1/2] 后端测试 + 覆盖率...${NC}"

if [ ! -d "$PROJECT_DIR/backend" ]; then
  echo -e "${YELLOW}  后端目录不存在，跳过${NC}"
else
  cd "$PROJECT_DIR/backend"
  if make coverage; then
    echo ""
    echo -e "${GREEN}  后端测试通过 ✓${NC}"
    if [ -f coverage.out ]; then
      COVERAGE=$(go tool cover -func=coverage.out | awk '/^total:/ {print $3}')
      echo -e "${GREEN}  语句覆盖率: ${COVERAGE}${NC}"
    fi
  else
    echo -e "${RED}  后端测试失败 ✗${NC}"
    FAILED=1
  fi
fi

# ===============================================
# 2. iOS 测试 + 核心覆盖率
# ===============================================
echo ""
echo -e "${YELLOW}[2/2] iOS 测试 + 核心覆盖率...${NC}"

if [ ! -d "$PROJECT_DIR/ios" ]; then
  echo -e "${YELLOW}  iOS 目录不存在，跳过${NC}"
else
  cd "$PROJECT_DIR/ios"
  SIMULATOR_ID=$(xcrun simctl list devices available 2>/dev/null | awk -F'[()]' '/iPhone/ {print $2; exit}' || true)
  if [ -z "$SIMULATOR_ID" ]; then
    echo -e "${RED}  没有可用的 iPhone Simulator ✗${NC}"
    FAILED=1
  else
    rm -rf /tmp/familypulse-ios-tests.xcresult /tmp/familypulse-ios-coverage.json
    if xcodebuild test \
      -project FamilyPulse.xcodeproj \
      -scheme FamilyPulse \
      -destination "platform=iOS Simulator,id=$SIMULATOR_ID" \
      -enableCodeCoverage YES \
      -collect-test-diagnostics never \
      -parallel-testing-enabled NO \
      -maximum-concurrent-test-simulator-destinations 1 \
      -resultBundlePath /tmp/familypulse-ios-tests.xcresult \
      CODE_SIGNING_ALLOWED=NO \
      > /tmp/xcodebuild.log 2>&1; then
      xcrun xccov view --report --json /tmp/familypulse-ios-tests.xcresult > /tmp/familypulse-ios-coverage.json
      if "$PROJECT_DIR/scripts/check_ios_coverage.py" /tmp/familypulse-ios-coverage.json 0.95; then
        echo -e "${GREEN}  iOS 测试和核心覆盖率通过 ✓${NC}"
      else
        echo -e "${RED}  iOS 核心覆盖率不足 ✗${NC}"
        FAILED=1
      fi
    else
      echo -e "${RED}  iOS 测试失败 ✗${NC}"
      tail -80 /tmp/xcodebuild.log
      FAILED=1
    fi
  fi
fi

# ===============================================
# 结果
# ===============================================
echo ""
if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}============================================${NC}"
  echo -e "${GREEN}  全部通过 ✓  可以提交${NC}"
  echo -e "${GREEN}============================================${NC}"
  exit 0
else
  echo -e "${RED}============================================${NC}"
  echo -e "${RED}  测试失败，请修复后重试${NC}"
  echo -e "${RED}============================================${NC}"
  exit 1
fi
