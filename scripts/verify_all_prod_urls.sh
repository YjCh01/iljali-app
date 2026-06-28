#!/usr/bin/env bash
# 모든 실서비스 URL HTTP 200 점검
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/environments.env

ok() { echo "  ✅ $1"; }
fail() { echo "  ❌ $1"; exit 1; }

BASE="${ILJARI_WEB_URL}"
API="${ILJARI_API_URL}"

check() {
  local url="$1" label="$2"
  local c
  c=$(curl -sk -o /dev/null -w '%{http_code}' -m 15 "${url}" 2>/dev/null || echo 0)
  [[ "${c}" =~ ^[23] ]] && ok "${label} ${url} → ${c}" || fail "${label} ${url} → ${c}"
}

echo "========================================"
echo "  실서비스 URL 점검"
echo "========================================"
check "${BASE}/" "개인"
check "${BASE}/corporate/" "기업"
check "${BASE}/admin/" "어드민"
check "${API}/health" "API"
echo "========================================"
