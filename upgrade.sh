#!/usr/bin/env bash
# shelf 一键升级脚本（Docker / fnOS 通用）
#
# 用法：
#   bash upgrade.sh                 # 备份数据库 → 拉取 latest → 重建容器 → 等待健康检查
#   bash upgrade.sh --no-backup     # 跳过升级前备份
#
# 说明：
#   - 必须在 install.sh 所在的仓库根目录执行；
#   - 复用现有 .env、数据目录和媒体挂载，不会重新询问配置；
#   - 升级前的数据库/密钥备份放在 backups/，默认保留最近 5 份；
#   - 镜像拉取失败或健康检查失败会打印日志和回滚命令。
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE_DIR="."
COMPOSE_FILE="$COMPOSE_DIR/docker-compose.yaml"
ENV_FILE="$COMPOSE_DIR/.env"
CONTAINER_NAME="shelf"
DEFAULT_IMAGE="ghcr.io/subject2019/shelf:latest"
BACKUP=1
BACKUP_DIR="${SHELF_BACKUP_DIR:-$COMPOSE_DIR/backups}"
KEEP_BACKUPS="${KEEP_BACKUPS:-5}"
TMP_DIR=""

log() { printf '\033[1;32m[shelf]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[shelf]\033[0m %s\n' "$*" >&2; }
die() { printf '\033[1;31m[shelf]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
用法: bash upgrade.sh [选项]

  --no-backup    跳过升级前自动备份
  -h, --help     显示帮助

脚本会复用当前目录的 docker-compose.yaml 和 .env，拉取 latest 镜像、
重建容器，并等待健康检查。升级前默认在线备份数据库到 backups/。
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-backup) BACKUP=0; shift ;;
        -h|--help) usage; exit 0 ;;
        *) die "未知参数：$1" ;;
    esac
done

cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
        rm -rf "$TMP_DIR"
    fi
}
trap cleanup EXIT

command -v docker >/dev/null 2>&1 || die "未找到 docker 命令"

if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
    DC="docker-compose"
else
    die "未找到 docker compose 或 docker-compose"
fi

[[ -f "$COMPOSE_FILE" ]] || die "未找到 $COMPOSE_FILE，请在 shelf-docker 仓库根目录运行"
[[ -f "$ENV_FILE" ]] || die "未找到 .env；请先运行 bash install.sh 完成首次部署"

if ! docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    die "未找到容器 $CONTAINER_NAME；首次安装请运行 bash install.sh"
fi

IMAGE_REF="$(awk '/^[[:space:]]*image:[[:space:]]*/ {print $2; exit}' "$COMPOSE_FILE" 2>/dev/null || true)"
IMAGE_REF="${IMAGE_REF:-$DEFAULT_IMAGE}"
OLD_IMAGE_ID="$(docker inspect -f '{{.Image}}' "$CONTAINER_NAME" 2>/dev/null || true)"

backup_before_upgrade() {
    if [[ "$BACKUP" -eq 0 ]]; then
        log "跳过升级前备份（--no-backup）"
        return 0
    fi

    if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
        warn "容器当前未运行，跳过在线备份"
        return 0
    fi

    mkdir -p "$BACKUP_DIR"
    TMP_DIR="$(mktemp -d)"

    log "备份数据库和密钥..."
    docker exec -i "$CONTAINER_NAME" python - <<'PY'
import sqlite3
src = sqlite3.connect("/data/config/echoshelf.db")
dst = sqlite3.connect("/data/config/.upgrade-backup.db")
with dst:
    src.backup(dst)
dst.close()
src.close()
print("db backup ok")
PY

    docker cp "$CONTAINER_NAME:/data/config/.upgrade-backup.db" "$TMP_DIR/echoshelf.db"
    docker cp "$CONTAINER_NAME:/data/config/secret.key" "$TMP_DIR/secret.key" 2>/dev/null \
        || warn "未找到 secret.key，跳过"
    docker exec -i "$CONTAINER_NAME" rm -f /data/config/.upgrade-backup.db || true

    local archive="$BACKUP_DIR/shelf-$(date +%Y%m%d-%H%M%S)-pre-upgrade.tar.gz"
    tar -czf "$archive" -C "$TMP_DIR" .
    log "备份完成：$archive"

    ls -1t "$BACKUP_DIR"/shelf-*.tar.gz 2>/dev/null \
        | tail -n +"$((KEEP_BACKUPS + 1))" \
        | xargs -r rm -f
}

log "当前镜像：$IMAGE_REF"
backup_before_upgrade

log "拉取最新镜像..."
if ! $DC -f "$COMPOSE_FILE" pull; then
    die "镜像拉取失败；私有包请先 docker login ghcr.io，检查网络后重试"
fi

log "重建容器..."
$DC -f "$COMPOSE_FILE" up -d --force-recreate --remove-orphans

log "等待健康检查（最多 150 秒）..."
STATUS=""
for _ in $(seq 1 75); do
    STATUS="$(docker inspect \
        -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' \
        "$CONTAINER_NAME" 2>/dev/null || echo missing)"
    case "$STATUS" in
        healthy|running) break ;;
        unhealthy|exited|dead|missing) break ;;
    esac
    printf '.'
    sleep 2
done
printf '\n'

if [[ "$STATUS" != "healthy" && "$STATUS" != "running" ]]; then
    warn "升级失败，容器状态：$STATUS"
    $DC -f "$COMPOSE_FILE" logs --tail=100 || true
    echo
    if [[ -n "$OLD_IMAGE_ID" ]]; then
        echo "旧镜像 ID：$OLD_IMAGE_ID"
        echo "回滚命令："
        echo "  docker tag $OLD_IMAGE_ID $IMAGE_REF"
        echo "  $DC -f \"$COMPOSE_FILE\" up -d --force-recreate --remove-orphans"
    fi
    exit 1
fi

VERSION="$(docker exec "$CONTAINER_NAME" python -c \
    "import json,urllib.request; print(json.load(urllib.request.urlopen('http://127.0.0.1:8080/api/v1/health'))['version'])" \
    2>/dev/null || true)"

echo
log "升级完成"
echo "  镜像: $IMAGE_REF"
[[ -n "$VERSION" ]] && echo "  版本: $VERSION"
echo "  容器: $CONTAINER_NAME ($STATUS)"
echo "  备份: $BACKUP_DIR"
