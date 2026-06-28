#!/bin/bash
cd "$(dirname "$0")"
source scripts/environments.env
clear
cat <<EOF
========================================
  일자리 — 들어가는 주소
========================================

  개인회원   ${ILJARI_WEB_URL}/
  기업회원   ${ILJARI_WEB_URL}/corporate/
  어드민     ${ILJARI_WEB_URL}/admin/

  ※ api.iljari.app/health = 서버 점검용 JSON (앱 아님)
    "status":"ok" 이면 정상

========================================
EOF
open "${ILJARI_WEB_URL}/"
read -r -p "Enter…" _
