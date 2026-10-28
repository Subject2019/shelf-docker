#!/usr/bin/env bash
# shelf 一键部署脚本（Docker / fnOS 通用）
# 用法：  bash install.sh
# 脚本会：① 询问媒体目录 / 数据目录 / 管理员用户名 / 映射端口 / 管理员密码  ② 生成 .env
#         ③ 拉取 ghcr.io/subject2019/shelf:latest 并核对本地与 ghcr 镜像一致性  ④ docker compose up -d  ⑤ 校验管理员账号
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE_DIR="."
ENV_EXAMPLE="$COMPOSE_DIR/.env.example"
ENV_FILE="$COMPOSE_DIR/.env"
IMAGE="ghcr.io/subject2019/shelf:latest"
CONTAINER_NAME="shelf"

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
read -r -p "管理员用户名（默认 admin，将自动转为小写）[$DEFAULT_USER]: " USERNAME
USERNAME="${USERNAME:-$DEFAULT_USER}"
while true; do
  read -r -p "映射端口（宿主机端口，容器固定 8080）[$DEFAULT_PORT]: " PORT
  PORT="${PORT:-$DEFAULT_PORT}"
  if [[ "$PORT" =~ ^[0-9]+$ ]] && [ "$PORT" -ge 1 ] && [ "$PORT" -le 65535 ]; then
    break
  fi
  echo "端口需为 1-65535 的数字，请重新输入。"
done

while true; do
  read -r -s -p "管理员密码（至少 8 位，留空则随机生成）: " PW
  echo
  if [ -z "$PW" ]; then
    PW="$(head -c 12 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 12)"
    echo "未输入密码，已随机生成: $PW  （请记好；忘记可用 docker exec 重置）"
    break
  fi
  if [ "${#PW}" -ge 8 ]; then
    break
  fi
  echo "密码至少需要 8 位，请重新输入（或直接回车随机生成）。"
done

mkdir -p "$MEDIA" "$DATA"

# 权限预检：媒体目录必须对容器运行用户可读，否则扫描读不到文件
if [ ! -r "$MEDIA" ] || [ ! -x "$MEDIA" ]; then
  echo "⚠️ 媒体目录当前用户不可读/不可进入：$MEDIA"
  echo "   容器以 PUID/PGID（默认 1000）运行，请确保该目录可读，例如："
  echo "     sudo chmod -R a+rX \"$MEDIA\""
  echo "   或在 .env 中把 PUID/PGID 调整为宿主机上拥有该目录的用户。"
fi

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

echo ">>> 拉取镜像（保证本地与 ghcr 一致）..."
$DC -f "$COMPOSE_DIR/docker-compose.yaml" pull

echo ">>> 校验本地镜像与 ghcr 一致性..."
REMOTE_DIGEST=$(docker buildx imagetools inspect "$IMAGE" --format '{{index .Manifest.Digest}}' 2>/dev/null || true)
LOCAL_DIGEST=$(docker inspect --format '{{index .RepoDigests 0}}' "$IMAGE" 2>/dev/null || true)
# 归一化：本地 RepoDigests 形如 ghcr.io/...@sha256:xxx，远端 digest 为 sha256:xxx，去掉仓库前缀再比
LOCAL_DIGEST="${LOCAL_DIGEST#*@}"
if [ -n "$REMOTE_DIGEST" ] && [ -n "$LOCAL_DIGEST" ]; then
  if [ "$REMOTE_DIGEST" = "$LOCAL_DIGEST" ]; then
    echo "✅ 本地镜像与 ghcr 一致: $LOCAL_DIGEST"
  else
    echo "⚠️ 本地镜像与 ghcr 不一致！本地=$LOCAL_DIGEST 远端=$REMOTE_DIGEST"
    echo "   请先执行: $DC -f \"$COMPOSE_DIR/docker-compose.yaml\" pull 后再部署"
  fi
elif [ -n "$REMOTE_DIGEST" ]; then
  echo "⚠️ 未能读取本地镜像 digest（可能拉取未完成或未登录 ghcr），远端 digest=$REMOTE_DIGEST"
else
  echo "⚠️ 无法获取 ghcr 远端 digest，请确认网络 / 登录状态（docker login ghcr.io）"
fi

echo ">>> 启动容器..."
$DC -f "$COMPOSE_DIR/docker-compose.yaml" up -d

echo ">>> 校验管理员账号（等待容器就绪）..."
CHECK_USER="${USERNAME,,}"
for i in $(seq 1 10); do
  sleep 2
  if docker ps -q -f "name=^${CONTAINER_NAME}$" | grep -q .; then break; fi
done
if docker exec "$CONTAINER_NAME" python -m app.cli admin list 2>/dev/null | grep -q "$CHECK_USER"; then
  echo "管理员账号已生效：$CHECK_USER"
else
  echo "⚠️ 未检测到期望的管理员 '$CHECK_USER'。可能数据目录已有旧管理员（环境变量仅在数据库为空时生效一次）。"
  echo "   如需使用 '$CHECK_USER'，请停止容器并清空 ECHOSHELF_DATA_PATH 后重新部署；"
  echo "   或执行：docker exec -it $CONTAINER_NAME python -m app.cli admin reset-password --username <实际用户名> --password '<新密码>'"
  echo "   当前实际管理员："
  docker exec "$CONTAINER_NAME" python -m app.cli admin list 2>/dev/null || echo "（无法读取，请手动执行 admin list 检查）"
fi

echo
echo "=== 完成 ==="
echo "镜像:   $IMAGE"
[ -n "$LOCAL_DIGEST" ] && echo "Digest: $LOCAL_DIGEST"
echo "WebUI:  http://<本机IP>:$PORT/   （在飞牛上端口以应用分配为准）"
echo "管理员: $USERNAME / $PW"
echo "媒体库: 网页端「设置 → 书库」添加 /audiobooks"
