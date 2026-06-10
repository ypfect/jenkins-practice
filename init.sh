#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin123"

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

echo "==> 启动 Jenkins + Registry"
cd "$ROOT"
docker compose up -d --build

echo "==> 等待 Jenkins 就绪"
for i in $(seq 1 60); do
  curl -sf -o /dev/null -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/api/json" 2>/dev/null && break
  sleep 5
done

echo "==> 配置 git proxy"
docker exec jenkins-local git config --global http.proxy "http://host.docker.internal:7890"
docker exec jenkins-local git config --global https.proxy "http://host.docker.internal:7890"
docker exec jenkins-local git config --global --add safe.directory '*'

echo ""
echo "平台就绪。"
echo "  Jenkins: ${JENKINS_URL}"
echo "  账号: ${JENKINS_USER} / ${JENKINS_PASS}"
echo ""
echo "如需注册 Job，运行: ./register-jobs.sh"
