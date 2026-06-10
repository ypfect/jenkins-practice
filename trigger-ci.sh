#!/usr/bin/env bash
# 模拟 QiQiOps 触发 Jenkins CI Job
set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin123}"

usage() {
  cat <<EOF
用法: $(basename "$0") [--branch main] [--env local] [--deploy-id 123]

示例:
  $(basename "$0") --branch main --env local --deploy-id 10001
EOF
  exit 1
}

BRANCH="main"
ENV="local"
DEPLOY_ID=""

while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --env) ENV="$2"; shift 2 ;;
    --deploy-id) DEPLOY_ID="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

CRUMB_JSON=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/crumbIssuer/api/json")
CRUMB=$(echo "${CRUMB_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['crumb'])")
CRUMB_FIELD=$(echo "${CRUMB_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['crumbRequestField'])")

echo "==> 触发 deepModel-ci"
echo "    Branch=${BRANCH}  Env=${ENV}  deployID=${DEPLOY_ID}"

curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
  -H "${CRUMB_FIELD}: ${CRUMB}" \
  -X POST \
  "${JENKINS_URL}/job/deepModel-ci/buildWithParameters?BRANCH=${BRANCH}&Env=${ENV}&deployID=${DEPLOY_ID}"

echo ""
echo "已提交。查看: ${JENKINS_URL}/job/deepModel-ci/"
