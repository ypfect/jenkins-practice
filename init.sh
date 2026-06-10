#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
JENKINS_URL="http://localhost:8080"
JENKINS_USER="admin"
JENKINS_PASS="admin123"

export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

jenkins_cli() {
  docker exec jenkins-local bash -lc \
    "curl -sf -o /tmp/jenkins-cli.jar http://localhost:8080/jnlpJars/jenkins-cli.jar >/dev/null && \
     /opt/java/openjdk/bin/java -jar /tmp/jenkins-cli.jar \
       -s http://localhost:8080/ -auth ${JENKINS_USER}:${JENKINS_PASS} $*"
}

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

echo "==> 注册 Job"
JOBS_DIR="${JOBS_DIR:-${ROOT}/jobs}"
if [ -d "$JOBS_DIR" ]; then
  for xml in "$JOBS_DIR"/*.xml; do
    [ -f "$xml" ] || continue
    job="$(basename "$xml" .xml)"
    docker exec -u root jenkins-local mkdir -p "/var/jenkins_home/jobs/${job}"
    docker cp "$xml" "jenkins-local:/var/jenkins_home/jobs/${job}/config.xml"
    docker exec -u root jenkins-local chown -R jenkins:jenkins "/var/jenkins_home/jobs/${job}"
    echo "    注册: ${job}"
  done
  jenkins_cli reload-configuration
else
  echo "    跳过: 未找到 jobs 目录 (${JOBS_DIR})"
fi

echo ""
echo "完成。"
echo "  Jenkins: ${JENKINS_URL}"
echo "  账号: ${JENKINS_USER} / ${JENKINS_PASS}"
