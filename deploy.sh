#!/bin/bash
set -euo pipefail

SERVER="${SERVER:-root@39.104.72.10}"
REMOTE_DIR="${REMOTE_DIR:-/opt/familypulse}"
PUBLIC_BASE_URL="${PUBLIC_BASE_URL:-https://jiaan.online}"

echo "============================================"
echo "  家安 FamilyPulse Go 后端部署"
echo "============================================"

cd "$(dirname "$0")"

require_cmd() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "缺少命令: $1"
        exit 1
    fi
}

for cmd in go docker rsync ssh scp curl openssl; do
    require_cmd "$cmd"
done

echo ""
echo "[1/6] 检查配置..."
if [ ! -f .env ]; then
    cp .env.example .env
    echo "  已创建 .env，请先填写 DB_PASSWORD 和 FAMILYPULSE_ADMIN_TOKEN 后重试。"
    exit 1
fi
for key in DB_PASSWORD FAMILYPULSE_ADMIN_TOKEN; do
    if ! grep -q "^${key}=" .env; then
        echo "  .env 缺少 ${key}，请补齐后重试。"
        exit 1
    fi
done
if grep -q "^FAMILYPULSE_APNS_ENABLED=true" .env; then
    for key in FAMILYPULSE_APNS_TEAM_ID FAMILYPULSE_APNS_KEY_ID FAMILYPULSE_APNS_PRIVATE_KEY; do
        if ! grep -q "^${key}=" .env; then
            echo "  ⚠️  .env 中 FAMILYPULSE_APNS_ENABLED=true 但缺少 ${key}"
            echo "  推送通知将无法正常工作，请补齐后重新部署。"
        fi
    done
fi
if [ ! -f ssl/fullchain.pem ] || [ ! -f ssl/privkey.pem ]; then
    echo "  拉取服务器证书或生成临时自签名证书..."
    mkdir -p ssl
    rsync -az "$SERVER:$REMOTE_DIR/ssl/" ssl/ 2>/dev/null || true
    if [ ! -f ssl/fullchain.pem ] || [ ! -f ssl/privkey.pem ]; then
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout ssl/privkey.pem -out ssl/fullchain.pem \
            -subj "/CN=jiaan.online" >/dev/null 2>&1
    fi
fi
echo "  配置检查通过"

echo ""
echo "[2/6] 本地测试并检查覆盖率..."
(cd backend && make coverage)
echo "  Go 测试覆盖率通过"

echo ""
echo "[3/6] 本地构建 Go 二进制..."
(cd backend && GOPROXY=https://goproxy.cn,direct go mod vendor && make build)
echo "  Go 二进制构建完成"

echo ""
echo "[4/6] 上传文件到服务器..."
ssh "$SERVER" "mkdir -p '$REMOTE_DIR/backend' '$REMOTE_DIR/ssl' '$REMOTE_DIR/landing'"
rsync -az --delete \
    --exclude 'bin/' \
    --exclude 'coverage*.out' \
    --exclude '.git/' \
    backend/ "$SERVER:$REMOTE_DIR/backend/"
scp docker-compose.prod.yml "$SERVER:$REMOTE_DIR/docker-compose.yml"
scp nginx.conf "$SERVER:$REMOTE_DIR/nginx.conf"
scp .env "$SERVER:$REMOTE_DIR/.env"
rsync -az --delete ssl/ "$SERVER:$REMOTE_DIR/ssl/"
rsync -az --delete landing/ "$SERVER:$REMOTE_DIR/landing/"
ssh "$SERVER" "chmod 600 '$REMOTE_DIR/.env'"
echo "  上传完成"

echo ""
echo "[5/6] 服务器构建并启动服务..."
ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose --env-file .env build backend"
ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose --env-file .env down --remove-orphans 2>/dev/null; docker compose --env-file .env up -d"

echo "  等待后端健康检查..."
for i in $(seq 1 60); do
    STATUS=$(ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose exec -T backend wget -q -O - http://127.0.0.1:8081/api/health 2>/dev/null || true")
    if echo "$STATUS" | grep -q '"status":"ok"'; then
        echo "  后端健康检查通过 ($((i * 3)) 秒)"
        break
    fi
    if [ "$i" -eq 60 ]; then
        echo "  后端启动超时，最近日志如下："
        ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose logs --tail=120 backend"
        exit 1
    fi
    sleep 3
done

echo "  重启 nginx..."
ssh "$SERVER" "cd '$REMOTE_DIR' && docker compose restart nginx >/dev/null"

echo ""
echo "[6/6] 验证公网接口..."
HEALTH=$(curl -fsS "$PUBLIC_BASE_URL/api/health")
if ! echo "$HEALTH" | grep -q '"status":"ok"'; then
    echo "  公网健康检查失败: $HEALTH"
    exit 1
fi

GUEST=$(curl -fsS -X POST "$PUBLIC_BASE_URL/api/auth/guest" \
    -H "Content-Type: application/json" \
    -d '{}')
if ! echo "$GUEST" | grep -q '"token"'; then
    echo "  公网 guest 登录验证失败: $GUEST"
    exit 1
fi

echo ""
echo "部署完成: $PUBLIC_BASE_URL"
