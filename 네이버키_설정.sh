#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -f "naver_map_client_id.txt" ]]; then
  cp -f "naver_map_client_id.txt.example" "naver_map_client_id.txt"
fi

echo "naver_map_client_id.txt 를 엽니다."
echo "NCP Application - Dynamic Map 의 Client ID 만 붙여넣고 저장하세요."
echo "Web URL: http://localhost:8080 , http://localhost"
echo

if [[ "$(uname)" == "Darwin" ]]; then
  open -e "naver_map_client_id.txt"
else
  "${EDITOR:-nano}" "naver_map_client_id.txt"
fi
