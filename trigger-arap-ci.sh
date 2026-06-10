#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin123}"

usage() {
  cat <<EOF
用法: $(basename "$0") [--branch main] [--env local] [--deploy-id 123]
EOF
  exit 1
}

BRANCH="main"; ENV="local"; DEPLOY_ID=""
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --env) ENV="$2"; shift 2 ;;
    --deploy-id) DEPLOY_ID="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

COOKIE_JAR=$(mktemp)
trap 'rm -f "${COOKIE_JAR}"' EXIT
CRUMB_JSON=$(curl -sf -c "${COOKIE_JAR}" -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/crumbIssuer/api/json")
CRUMB=$(echo "${CRUMB_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['crumb'])")
CRUMB_FIELD=$(echo "${CRUMB_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['crumbRequestField'])")

echo "==> 触发 arap-ci"
echo "    Branch=${BRANCH}  Env=${ENV}  deployID=${DEPLOY_ID}"

curl -sf -b "${COOKIE_JAR}" -u "${JENKINS_USER}:${JENKINS_PASS}" \
  -H "${CRUMB_FIELD}: ${CRUMB}" \
  -X POST \
  "${JENKINS_URL}/job/arap-ci/buildWithParameters?Branch=${BRANCH}&Env=${ENV}&deployID=${DEPLOY_ID}"

echo ""
echo "已提交。查看: ${JENKINS_URL}/job/arap-ci/"
