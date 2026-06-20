#!/bin/bash
cd "$(dirname "$0")"
chmod +x 네이버키_설정.sh 2>/dev/null
./네이버키_설정.sh
echo ""
echo "저장 후 웹 실행.command 또는 QC 실행.command 를 더블클릭하세요."
read -r -p "Enter 키를 누르면 이 창이 닫힙니다…"
