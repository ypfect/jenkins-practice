#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

# 先停掉流水线用 docker run 起的业务容器（deepmodel-app/appx-app/arap-app 等，不归 compose 管），
# 否则 arap-app 占用 practice_default 网络会导致 compose down 报 "Resource is still in use"
APP_CONTAINERS=$(docker ps -aq --filter "name=-app")
if [ -n "${APP_CONTAINERS}" ]; then
  echo "停止业务容器..."
  docker rm -f ${APP_CONTAINERS}
fi

docker compose down

echo "已停止。下次启动: docker compose up -d"
