#!/bin/bash
set -euo pipefail

# 服务器初始化脚本（仅在首次配置时运行一次）
SERVER="root@39.104.72.10"

echo "============================================"
echo " FamilyPulse 服务器优化"
echo "============================================"

# ── Docker 镜像加速 + 日志轮转 ─────────────────
echo ""
echo "[1/3] 配置 Docker 镜像加速和日志轮转..."
ssh "$SERVER" "cat > /etc/docker/daemon.json << 'EOF'
{
  \"log-driver\": \"json-file\",
  \"log-opts\": {
    \"max-size\": \"10m\",
    \"max-file\": \"3\"
  },
  \"registry-mirrors\": [
    \"https://docker.m.daocloud.io\",
    \"https://dockerproxy.com\",
    \"https://docker.nju.edu.cn\"
  ]
}
EOF"

echo "  ⚠️  需要重启 Docker（会中断 SSH，重启后重新连接即可）"
ssh "$SERVER" "systemctl restart docker"
echo "  ✅ Docker 配置已更新"

# ── 系统层面优化参数 ────────────────────
echo ""
echo "[2/3] 设置系统参数..."
ssh "$SERVER" "cat > /etc/sysctl.d/99-familypulse.conf << 'EOF'
# FamilyPulse 优化参数
# 降低 swap 倾向（仅在有 swap 时有效）
vm.swappiness=10
EOF"
ssh "$SERVER" "sysctl -p /etc/sysctl.d/99-familypulse.conf"
echo "  ✅ 系统参数已更新"

# ── 清理旧资源 ──────────────────────────
echo ""
echo "[3/3] 清理未使用的 Docker 镜像..."
ssh "$SERVER" "docker system prune -af --filter 'until=24h' 2>/dev/null || true"
echo ""
echo "============================================"
echo " 优化完成！"
echo "============================================"
echo ""
echo "注意事项："
echo "  - 如果 Docker 重启导致 SSH 断开，等 10 秒重连即可"
echo "  - 不要额外设置 vm.overcommit_memory=2（会导致 Docker 无法分配内存）"
