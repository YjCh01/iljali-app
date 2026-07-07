#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/set_juso_key_on_server.sh

echo "========================================"
echo "  Juso(도로명주소) 승인키 → 서버 등록"
echo "========================================"
echo ""
echo "business.juso.go.kr 에서 발급받은 검색 API 승인키를 붙여넣으세요."
echo "(팝업 API 키가 아닌 검색 API 키여야 합니다)"
echo ""

read -r -p "JUSO 승인키 (confmKey): " JUSO_KEY
echo ""

if [[ -z "${JUSO_KEY}" ]]; then
  echo "승인키를 입력해야 합니다."
  read -r -p "엔터를 누르면 종료합니다."
  exit 1
fi

echo "[진행] 서버 접속 중… (비밀번호 물어보면 root 비밀번호 입력)"
echo ""

./scripts/set_juso_key_on_server.sh "${JUSO_KEY}"

echo ""
echo "완료. 브라우저에서 확인:"
echo "  https://api.iljari.app/health"
echo "  → juso_configured: true 이면 성공"
echo ""
echo "주소 검색 테스트:"
echo "  https://api.iljari.app/v1/addresses/search?keyword=송파구"
echo ""
read -r -p "엔터를 누르면 종료합니다."
