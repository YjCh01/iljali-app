#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/set_naver_oauth_on_server.sh

echo "========================================"
echo "  네이버 로그인 키 → 서버 등록"
echo "========================================"
echo ""
echo "네이버 개발자센터에서 복사한 값을 붙여넣으세요."
echo ""

read -r -p "Client ID: " CLIENT_ID
read -r -s -p "Client Secret (입력해도 화면에 안 보임): " CLIENT_SECRET
echo ""
echo ""

if [[ -z "${CLIENT_ID}" || -z "${CLIENT_SECRET}" ]]; then
  echo "ID와 Secret을 모두 입력해야 합니다."
  read -r -p "엔터를 누르면 종료합니다."
  exit 1
fi

echo "[진행] 서버 접속 중… (비밀번호 물어보면 root 비밀번호 입력)"
echo ""

./scripts/set_naver_oauth_on_server.sh "${CLIENT_ID}" "${CLIENT_SECRET}"

echo ""
echo "완료. 브라우저에서 확인:"
echo "  https://api.iljari.app/v1/auth/social/status"
echo "  → naver: true 이면 성공"
echo ""
read -r -p "엔터를 누르면 종료합니다."
