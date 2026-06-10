#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "${ROOT}"

docker compose down

echo "已停止。下次启动: docker compose up -d"
