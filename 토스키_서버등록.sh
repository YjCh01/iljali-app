#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/set_toss_keys_on_server.sh

echo "========================================"
echo "  토스 PG 키 → 서버 등록"
echo "  (가맹 심사 승인 후)"
echo "========================================"
echo ""
echo "토스페이먼츠에서 live_ck_ / live_sk_ 수령 후 입력하세요."
echo "등록 시 무료 노출 프로모션(FREE_EXPOSURE_PROMO)은 자동 OFF 됩니다."
echo ""

read -r -p "TOSS_CLIENT_KEY (live_ck_...): " CLIENT_KEY
read -r -s -p "TOSS_SECRET_KEY (live_sk_...): " SECRET_KEY
echo ""
read -r -s -p "TOSS_WEBHOOK_SECRET (선택, Enter=건너뜀): " WEBHOOK_SECRET
echo ""

if [[ -z "${CLIENT_KEY}" || -z "${SECRET_KEY}" ]]; then
  echo "Client Key와 Secret Key는 필수입니다."
  read -r -p "Enter…" _
  exit 1
fi

echo ""
echo "[진행] 서버 접속… (root 비밀번호)"
./scripts/set_toss_keys_on_server.sh "${CLIENT_KEY}" "${SECRET_KEY}" "${WEBHOOK_SECRET}"

echo ""
echo "다음: 도구_웹만배포.command → iljari.app/pricing 실결제 1건 테스트"
read -r -p "Enter…" _
