#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/environments.env
clear
cat docs/SITE_ACCESS.md
echo ""
for u in "${ILJARI_WEB_URL}/" "${ILJARI_API_URL}/health"; do
  c=$(curl -sk -o /dev/null -w '%{http_code}' -m 10 "$u" 2>/dev/null || echo 0)
  echo "  $u → HTTP $c"
done
echo ""
[[ "$(uname)" == "Darwin" ]] && open "${ILJARI_WEB_URL}/"
read -r -p "Enter…" _
