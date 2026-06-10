#!/usr/bin/env bash
set -uo pipefail
#
# 镜像清理脚本，分两层：
#   1. Docker 宿主机：清理 CI 构建残留的业务镜像，只保留平台镜像
#   2. Registry：只保留最新 N 个 tag，删除旧的并回收磁盘
#
# 用法：
#   ./cleanup.sh              # 预览要清理什么（dry-run）
#   ./cleanup.sh --run        # 真正执行
#   KEEP=5 ./cleanup.sh --run # 保留最新 5 个 tag（默认 3）

KEEP="${KEEP:-3}"
REGISTRY="http://localhost:5050"
DRY_RUN=true
[ "${1:-}" = "--run" ] && DRY_RUN=false

run_cmd() {
  if $DRY_RUN; then
    echo "  [dry-run] $*"
  else
    eval "$@"
  fi
}

echo "=============================="
echo " 1. Docker 宿主机：清理业务镜像"
echo "=============================="

PLATFORM_PATTERNS="jenkins|registry|maven|eclipse-temurin|openjdk|docker|node"
HOST_CLEANUP=()
while IFS= read -r line; do
  repo=$(echo "$line" | awk '{print $1}')
  tag=$(echo "$line" | awk '{print $2}')
  [[ "$repo" == "REPOSITORY" ]] && continue
  [[ "$repo" == "<none>" ]] && HOST_CLEANUP+=("${repo}:${tag}") && continue
  if echo "$repo" | grep -qE "$PLATFORM_PATTERNS"; then
    continue
  fi
  HOST_CLEANUP+=("${repo}:${tag}")
done < <(docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}")

if [ ${#HOST_CLEANUP[@]} -eq 0 ]; then
  echo "  无需清理。"
else
  echo "  将删除 ${#HOST_CLEANUP[@]} 个宿主机镜像："
  for img in "${HOST_CLEANUP[@]}"; do
    size=$(docker images --format "{{.Repository}}:{{.Tag}} {{.Size}}" | grep "^${img} " | awk '{print $2}')
    echo "    - ${img}  (${size})"
  done
  for img in "${HOST_CLEANUP[@]}"; do
    run_cmd "docker rmi '${img}' 2>/dev/null || true"
  done
fi

echo ""
echo "=============================="
echo " 2. Registry：保留最新 ${KEEP} 个 tag"
echo "=============================="

REPOS=$(curl -sf "${REGISTRY}/v2/_catalog" 2>/dev/null | python3 -c "import sys,json; print('\n'.join(json.load(sys.stdin).get('repositories',[])))" 2>/dev/null || true)

if [ -z "$REPOS" ]; then
  echo "  Registry 未运行或无镜像。"
else
  for repo in $REPOS; do
    TAGS_JSON=$(curl -sf "${REGISTRY}/v2/${repo}/tags/list" 2>/dev/null || echo '{}')
    TAGS=$(echo "$TAGS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
tags = [t for t in data.get('tags', []) if t != 'latest']
tags.sort(key=lambda t: int(t) if t.isdigit() else 0)
for t in tags:
    print(t)
" 2>/dev/null)

    TAG_COUNT=$(echo "$TAGS" | grep -c . || true)
    if [ "$TAG_COUNT" -le "$KEEP" ]; then
      echo "  ${repo}: ${TAG_COUNT} 个 tag，不超过 ${KEEP}，跳过。"
      continue
    fi

    TO_KEEP=$(echo "$TAGS" | tail -n "${KEEP}")
    TO_DELETE=$(echo "$TAGS" | python3 -c "import sys; lines=sys.stdin.read().strip().split('\n'); [print(l) for l in lines[:-${KEEP}]]" 2>/dev/null)
    echo "  ${repo}: 共 ${TAG_COUNT} 个 tag"
    echo "    保留: $(echo $TO_KEEP | tr '\n' ' ') + latest"
    echo "    删除: $(echo $TO_DELETE | tr '\n' ' ')"

    for tag in $TO_DELETE; do
      DIGEST=$(curl -sf -I -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "${REGISTRY}/v2/${repo}/manifests/${tag}" 2>/dev/null | grep -i "Docker-Content-Digest" | awk '{print $2}' | tr -d '\r')
      if [ -n "$DIGEST" ]; then
        run_cmd "curl -s -o /dev/null -w '%{http_code}' -X DELETE '${REGISTRY}/v2/${repo}/manifests/${DIGEST}' || true"
      else
        echo "    [跳过] ${tag}: 无法获取 digest"
      fi
    done
  done

  if ! $DRY_RUN; then
    echo ""
    echo "  回收 Registry 磁盘空间..."
    docker exec registry bin/registry garbage-collect /etc/docker/registry/config.yml --delete-untagged 2>/dev/null || \
      echo "  [提示] 需要 Registry 启用 delete 才能回收，见下方说明。"
  fi
fi

echo ""
echo "=============================="
echo " 3. Docker 系统级清理"
echo "=============================="
echo "  清理悬空镜像、停止的容器、无用网络..."
run_cmd "docker system prune -f"

if $DRY_RUN; then
  echo ""
  echo "以上为预览。确认无误后执行: ./cleanup.sh --run"
fi
