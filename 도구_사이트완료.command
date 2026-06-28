#!/bin/bash
cd "$(dirname "$0")"
clear
cat <<'EOF'
========================================
  iljari.app 전체 배포 (HTTPS + 웹)
========================================

  NCP 서버 root 비밀번호 1번 입력됩니다.
  (맥 로그인 비번 아님)

  NCP 콘솔 → ACG 인바운드 TCP 443 열려있어야 합니다.

========================================
EOF
exec ./scripts/finish_site_deploy.sh
