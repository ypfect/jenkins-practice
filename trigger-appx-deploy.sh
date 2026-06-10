#!/usr/bin/env bash
set -euo pipefail

JENKINS_URL="${JENKINS_URL:-http://localhost:8080}"
JENKINS_USER="${JENKINS_USER:-admin}"
JENKINS_PASS="${JENKINS_PASS:-admin123}"

usage() {
  cat <<EOF
用法: $(basename "$0") --image localhost:5050/appx:1 [--env local] [--deploy-id 123] [--ci-build 1]

示例:
  $(basename "$0") --image localhost:5050/appx:3 --env local --deploy-id 10001 --ci-build 3
EOF
  exit 1
}

IMAGE=""
ENV="local"
DEPLOY_ID=""
CI_BUILD=""

while [ $# -gt 0 ]; do
  case "$1" in
    --image) IMAGE="$2"; shift 2 ;;
    --env) ENV="$2"; shift 2 ;;
    --deploy-id) DEPLOY_ID="$2"; shift 2 ;;
    --ci-build) CI_BUILD="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "未知参数: $1"; usage ;;
  esac
done

[ -n "${IMAGE}" ] || usage

ENCODED_IMAGE=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${IMAGE}'))")

CRUMB_JSON=$(curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" "${JENKINS_URL}/crumbIssuer/api/json")
CRUMB=$(echo "${CRUMB_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['crumb'])")
CRUMB_FIELD=$(echo "${CRUMB_JSON}" | python3 -c "import sys,json; print(json.load(sys.stdin)['crumbRequestField'])")

echo "==> 触发 appx-deploy"
echo "    IMAGE=${IMAGE}  Env=${ENV}  deployID=${DEPLOY_ID}  CI_BUILD=${CI_BUILD}"

curl -sf -u "${JENKINS_USER}:${JENKINS_PASS}" \
  -H "${CRUMB_FIELD}: ${CRUMB}" \
  -X POST \
  "${JENKINS_URL}/job/appx-deploy/buildWithParameters?IMAGE=${ENCODED_IMAGE}&Env=${ENV}&deployID=${DEPLOY_ID}&CI_BUILD=${CI_BUILD}"

echo ""
echo "已提交。查看: ${JENKINS_URL}/job/appx-deploy/"
