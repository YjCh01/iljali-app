#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
source scripts/server_dev.sh
source scripts/environments.env

echo "========================================"
echo "  iljari.app 진단"
echo "========================================"
ok() { echo "  ✅ $*"; }
fail() { echo "  ❌ $*"; }

if curl -sk "${ILJARI_API_URL}/health" >/dev/null 2>&1; then
  ok "API ${ILJARI_API_URL}/health"
else
  fail "API ${ILJARI_API_URL}"
fi

for d in api.iljari.app www.iljari.app iljari.app; do
  ip="$(dig +short "$d" A 2>/dev/null | head -1)"
  [[ -n "${ip}" ]] && ok "DNS $d → $ip" || fail "DNS $d"
done

if curl -sk -o /dev/null "${ILJARI_WEB_URL}/" 2>/dev/null; then
  ok "Web ${ILJARI_WEB_URL}/"
else
  fail "Web ${ILJARI_WEB_URL}/ — 도구_사이트완료.command"
fi

echo ""
echo "========================================"
read -r -p "Enter…" _ 2>/dev/null || true
