#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "  iljari.app 서비스 상태"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "========================================"
echo ""

health="$(curl -sS -m 15 https://api.iljari.app/health 2>/dev/null || echo '{}')"
echo "[API health]"
echo "${health}" | python3 -m json.tool 2>/dev/null || echo "${health}"
echo ""

check_flag() {
  local key="$1" label="$2"
  if echo "${health}" | python3 -c "import sys,json; d=json.load(sys.stdin); sys.exit(0 if d.get('${key}') else 1)" 2>/dev/null; then
    echo "  ✅ ${label}"
  else
    echo "  ❌ ${label}"
  fi
}

echo "[핵심 플래그]"
check_flag "free_exposure_promo" "무료 노출 프로모션"
check_flag "juso_configured" "Juso 주소 검색"
check_flag "kakao_geocode_configured" "Kakao 좌표(지오코딩)"
check_flag "nts_configured" "국세청 사업자 검증"
check_flag "auth_configured" "인증(JWT)"
python3 -c "
import json, sys
d = json.loads('''${health}''')
sms = d.get('sms_provider', '')
print('  ✅ Aligo SMS' if sms == 'aligo' else f'  ❌ SMS ({sms or \"미설정\"})')
print('  ✅ 소셜 로그인 실연동' if not d.get('social_auth_mock') else '  ❌ 소셜 mock')
print('  ⏳ 토스 PG 대기' if not d.get('toss_configured') else '  ✅ 토스 PG')
"
echo ""

echo "[주소 API 샘플]"
geo="$(curl -sS -m 15 'https://api.iljari.app/v1/addresses/geocode?q=%EC%84%9C%EC%9A%B8%ED%8A%B9%EB%B3%84%EC%8B%9C+%EC%86%A1%ED%8C%8C%EA%B5%AC+%EC%98%A4%EA%B8%8811%EA%B8%B8+55' 2>/dev/null || echo '{}')"
echo "${geo}" | python3 -m json.tool 2>/dev/null || echo "${geo}"
echo ""

echo "========================================"
echo "  웹: https://iljari.app"
echo "  배포: 도구_웹만배포.command"
echo "========================================"
read -r -p "Enter…" _ 2>/dev/null || true
