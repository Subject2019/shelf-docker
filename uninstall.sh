#!/usr/bin/env bash
# shelf 一键卸载脚本（Docker / fnOS 通用）
# 用法：  bash uninstall.sh
# 行为：  ① 停止并移除 shelf 容器
#         ② 询问是否移除镜像 ghcr.io/subject2019/shelf:latest
#         ③ 询问是否删除数据目录（不可逆，默认保留）
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE_DIR="."
IMAGE="ghcr.io/subject2019/shelf:latest"
CONTAINER_NAME="shelf"

# docker compose v2 / v1 兼容
if docker compose version >/dev/null 2>&1; then DC="docker compose"; else DC="docker-compose"; fi

echo "=== shelf 卸载 ==="

# 1) 停止并移除容器（优先 compose，回退到 docker rm）
if [ -f "$COMPOSE_DIR/docker-compose.yaml" ]; then
  $DC -f "$COMPOSE_DIR/docker-compose.yaml" down 2>/dev/null || true
fi
if docker ps -a --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
  docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true
  echo "已停止并移除容器 $CONTAINER_NAME"
else
  echo "未找到 $CONTAINER_NAME 容器（可能已停止或未安装）"
fi

# 2) 是否移除镜像
read -r -p "是否移除镜像 $IMAGE ？(y/N): " RM_IMG
if [[ "$RM_IMG" =~ ^[Yy]$ ]]; then
  if docker rmi -f "$IMAGE" >/dev/null 2>&1; then
    echo "已移除镜像 $IMAGE"
  else
    echo "镜像移除失败或不存在（可能仍被其他容器引用）"
  fi
else
  echo "保留镜像（重装时无需重新拉取）"
fi

# 3) 是否删除数据目录（尝试从 .env 或容器挂载反查路径）
DATA=""
if [ -f "$COMPOSE_DIR/.env" ]; then
  DATA="$(grep -E '^ECHOSHELF_DATA_PATH=' "$COMPOSE_DIR/.env" | cut -d= -f2-)"
fi
if [ -n "$DATA" ]; then
  echo "数据目录：$DATA"
  read -r -p "是否删除该数据目录（数据库/封面缓存，删除后不可逆）？(y/N): " RM_DATA
  if [[ "$RM_DATA" =~ ^[Yy]$ ]]; then
    if rm -rf "$DATA"; then
      echo "已删除数据目录 $DATA"
    else
      echo "删除失败，请手动删除：$DATA"
    fi
  else
    echo "保留数据目录 $DATA"
  fi
else
  echo "未定位到数据目录；如需清理，请手动删除你之前指定的 ECHOSHELF_DATA_PATH"
fi

echo "=== 卸载完成 ==="
