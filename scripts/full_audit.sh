#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/environments.env

ok()  { echo "  ✅ $*"; }
fail(){ echo "  ❌ $*"; }
warn(){ echo "  ⚠️  $*"; }

echo "========================================"
echo "  iljari.app 점검"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "========================================"

echo ""
echo "[1] DNS"
for d in iljari.app www.iljari.app api.iljari.app; do
  ip="$(dig +short "$d" A 2>/dev/null | head -1)"
  [[ -n "${ip}" ]] && ok "$d → $ip" || fail "$d DNS 없음"
done

echo ""
echo "[2] HTTPS"
check() {
  local url="$1" label="$2"
  local code
  code=$(curl -sk -o /dev/null -w "%{http_code}" -m 12 "$url" 2>/dev/null || echo 0)
  [[ "$code" =~ ^[23] ]] && ok "$label → $code" || fail "$label → $code ($url)"
}
check "https://iljari.app/" "개인"
check "https://iljari.app/corporate/" "기업"
check "https://iljari.app/admin/" "어드민"
check "https://api.iljari.app/health" "API"

echo ""
echo "[3] 이 맥 DNS"
local_ip="$(dscacheutil -q host -a name iljari.app 2>/dev/null | awk '/ip_address:/{print $2; exit}')"
[[ -n "${local_ip}" ]] && ok "iljari.app → ${local_ip}" || warn "iljari.app 캐시 없음"

echo ""
echo "========================================"
echo "  주소: https://iljari.app/"
echo "  배포: 도구_웹전체배포.command"
echo "========================================"
read -r -p "Enter…" _ 2>/dev/null || true
