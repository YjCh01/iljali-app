#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# shellcheck source=scripts/remote_api.env
source scripts/remote_api.env
clear
cat docs/GABIA_DNS.md
echo ""
echo "========================================"
echo "  현재 DNS 상태"
echo "========================================"
for d in api.iljari.app www.iljari.app iljari.app; do
  if host -t A "$d" >/dev/null 2>&1; then
    echo "  OK   $d → $(host -t A "$d" | awk '/address/{print $4; exit}')"
  else
    echo "  ---- $d (미설정)"
  fi
done
echo ""
echo "Web URL: $(cd "$(dirname "$0")/.." && source scripts/server_dev.sh 2>/dev/null; iljari_resolve_web_base_url 2>/dev/null || echo "http://iljari.app")/"
read -r -p "Enter…" _
