#!/usr/bin/env bash
# shelf 一键部署脚本（Docker / fnOS 通用）
# 用法：  bash install.sh
# 脚本会：① 询问媒体目录 / 数据目录 / 管理员密码  ② 生成 .env
#         ③ 拉取 ghcr.io/subject2019/shelf:latest  ④ docker compose up -d
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE_DIR="."
ENV_EXAMPLE="$COMPOSE_DIR/.env.example"
ENV_FILE="$COMPOSE_DIR/.env"
IMAGE="ghcr.io/subject2019/shelf:latest"

DEFAULT_MEDIA="/volume1/media/audiobooks"
DEFAULT_DATA="/volume1/docker/shelf"
DEFAULT_USER="admin"
DEFAULT_PORT="8080"

# docker compose v2 / v1 兼容
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "=== shelf 一键部署 ==="
echo "镜像: $IMAGE"

read -r -p "媒体目录（有声书文件，容器内只读挂载）[$DEFAULT_MEDIA]: " MEDIA
MEDIA="${MEDIA:-$DEFAULT_MEDIA}"
read -r -p "数据目录（数据库/缓存，必须本地盘）[$DEFAULT_DATA]: " DATA
DATA="${DATA:-$DEFAULT_DATA}"
read -r -p "管理员用户名（默认 admin）[$DEFAULT_USER]: " USERNAME
USERNAME="${USERNAME:-$DEFAULT_USER}"
while true; do
  read -r -p "映射端口（宿主机端口，容器固定 8080）[$DEFAULT_PORT]: " PORT
  PORT="${PORT:-$DEFAULT_PORT}"
  if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
    break
  fi
  echo "端口需为 1-65535 的数字，请重新输入。"
done

read -r -s -p "管理员密码（至少 8 位，留空则随机生成）: " PW
echo
if [ -z "$PW" ]; then
  PW="$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 12)"
  echo "未输入密码，已随机生成: $PW  （请记好；忘记可用 docker exec 重置）"
fi

mkdir -p "$MEDIA" "$DATA"

# 生成 .env（覆盖式写入，避免重复 key；其余变量在 compose 中已有默认值）
cat > "$ENV_FILE" <<EOF
# shelf 部署环境变量（由 install.sh 生成）
AUDIOBOOKS_PATH=$MEDIA
ECHOSHELF_DATA_PATH=$DATA
SHELF_HOST_PORT=$PORT
ECHOSHELF_ADMIN_USERNAME=$USERNAME
ECHOSHELF_ADMIN_PASSWORD=$PW
EOF

echo "已生成 $ENV_FILE"

echo ">>> 拉取镜像..."
$DC -f "$COMPOSE_DIR/docker-compose.yaml" pull
echo ">>> 启动容器..."
$DC -f "$COMPOSE_DIR/docker-compose.yaml" up -d

echo
echo "=== 完成 ==="
echo "WebUI:  http://<本机IP>:$PORT/   （在飞牛上端口以应用分配为准）"
echo "管理员: $USERNAME / $PW"
echo "媒体库: 网页端「设置 → 书库」添加 /audiobooks"
