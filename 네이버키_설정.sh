#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f "naver_map_client_id.txt" ]]; then
  cp -f "naver_map_client_id.txt.example" "naver_map_client_id.txt"
fi

echo "naver_map_client_id.txt 를 엽니다."
echo "NCP Application - Dynamic Map 의 Client ID 만 붙여넣고 저장하세요."
echo ""
echo "  ★ Web URL (+ 추가) — www·포트 금지:"
echo "    http://iljari.app"
echo "    http://localhost"
echo "    http://127.0.0.1"
echo "    (X) http://www.iljari.app  ← 이거 오류남"
echo "    (X) http://localhost:8080"
echo ""
echo "  자세히: docs/NAVER_NCP_SETUP.md · 도구_네이버지도_URL.command"
echo

if [[ "$(uname)" == "Darwin" ]]; then
  open -e "naver_map_client_id.txt"
else
  "${EDITOR:-nano}" "naver_map_client_id.txt"
fi
