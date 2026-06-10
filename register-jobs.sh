#!/usr/bin/env bash
set -euo pipefail
#
# 扫描 config/*/jobs/*.xml，注册（或更新）到 Jenkins。
#
# 用法：
#   ./register-jobs.sh                       # 扫描所有项目
#   ./register-jobs.sh deepModel             # 只注册指定项目
#   ./register-jobs.sh deepModel anotherApp  # 注册多个项目
#
# 对标公司模式：Job 壳子注册一次，之后改 Jenkinsfile push 即生效。

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${ROOT}/../config"
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

# 检查 Jenkins 是否在跑
if ! curl -sf -o /dev/null -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/api/json" 2>/dev/null; then
  echo "错误: Jenkins 未运行。请先执行 ./init.sh"
  exit 1
fi

# 确定要扫描的项目目录
if [ $# -gt 0 ]; then
  PROJECTS=("$@")
else
  PROJECTS=()
  for d in "${CONFIG_DIR}"/*/jobs; do
    [ -d "$d" ] || continue
    PROJECTS+=("$(basename "$(dirname "$d")")")
  done
fi

if [ ${#PROJECTS[@]} -eq 0 ]; then
  echo "未找到任何项目。请检查 config/<project>/jobs/ 目录。"
  exit 1
fi

COUNT=0
for project in "${PROJECTS[@]}"; do
  jobs_dir="${CONFIG_DIR}/${project}/jobs"
  if [ ! -d "$jobs_dir" ]; then
    echo "跳过: ${project}（未找到 ${jobs_dir}）"
    continue
  fi
  for xml in "${jobs_dir}"/*.xml; do
    [ -f "$xml" ] || continue
    job="$(basename "$xml" .xml)"
    docker exec -u root jenkins-local mkdir -p "/var/jenkins_home/jobs/${job}"
    docker cp "$xml" "jenkins-local:/var/jenkins_home/jobs/${job}/config.xml"
    docker exec -u root jenkins-local chown -R jenkins:jenkins "/var/jenkins_home/jobs/${job}"
    echo "  注册: ${job}  ← ${project}/jobs/$(basename "$xml")"
    COUNT=$((COUNT + 1))
  done
done

if [ "$COUNT" -gt 0 ]; then
  jenkins_cli reload-configuration
  echo ""
  echo "完成，共注册 ${COUNT} 个 Job。"
  echo "之后修改流水线只需 push Jenkinsfile，不用重新注册。"
else
  echo "没有找到 XML 文件。"
fi
