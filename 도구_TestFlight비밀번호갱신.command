#!/bin/bash
# Finder에서 더블클릭 → TestFlight 앱 전용 비밀번호 갱신 (+ 업로드)
cd "$(dirname "$0")" || exit 1
chmod +x scripts/refresh_testflight_password.sh 2>/dev/null
./scripts/refresh_testflight_password.sh
echo ""
echo "창을 닫으려면 Enter…"
read -r _
