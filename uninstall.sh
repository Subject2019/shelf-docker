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

# 3) 是否删除数据目录（优先从 .env 读取 ECHOSHELF_DATA_PATH）
DATA=""
if [ -f "$COMPOSE_DIR/.env" ]; then
  # 加 || true：grep 无匹配时不会因 set -e/pipefail 提前退出
  DATA="$(grep -E '^ECHOSHELF_DATA_PATH=' "$COMPOSE_DIR/.env" | head -1 | cut -d= -f2- || true)"
fi
DATA="${DATA%$'\r'}"   # 去掉可能的 CRLF 回车
if [ -n "$DATA" ]; then
  echo "数据目录：$DATA"
  read -r -p "是否删除该数据目录（数据库/封面缓存，删除后不可逆）？(y/N): " RM_DATA
  if [[ "$RM_DATA" =~ ^[Yy]$ ]]; then
    if [ ! -e "$DATA" ]; then
      echo "数据目录不存在（可能已删除）：$DATA"
    elif rm -rf "$DATA" 2>/dev/null; then
      echo "已删除数据目录 $DATA"
    elif command -v sudo >/dev/null 2>&1 && sudo rm -rf "$DATA"; then
      # 目录常由容器以 root/PUID 创建，普通用户删不掉时用 sudo 兜底
      echo "已删除数据目录 $DATA（sudo）"
    else
      echo "删除失败（可能是权限不足）：请手动执行  sudo rm -rf \"$DATA\""
    fi
    if [ -e "$DATA" ]; then
      echo "⚠️ 数据目录仍然存在：$DATA（请检查权限后重试）"
    fi
  else
    echo "保留数据目录 $DATA"
  fi
else
  echo "未定位到数据目录（.env 中无 ECHOSHELF_DATA_PATH）；如需彻底清理，请手动删除之前指定的数据目录。"
fi

echo "=== 卸载完成 ==="
