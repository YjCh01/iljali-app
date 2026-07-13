#!/bin/bash
# Finder에서 더블클릭 → 기존 map.ipa 만 TestFlight 업로드
# 비밀번호 오류 나면: 도구_TestFlight비밀번호갱신.command 먼저
cd "$(dirname "$0")" || exit 1
chmod +x scripts/upload_testflight.sh 2>/dev/null
./scripts/upload_testflight.sh --upload-only
STATUS=$?
if [[ "${STATUS}" -ne 0 ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  업로드 실패 — 비밀번호가 틀린 경우가 많습니다"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  echo "  👉 Finder에서 이 파일을 더블클릭하세요:"
  echo "     도구_TestFlight비밀번호갱신.command"
  echo ""
  echo "  (Apple 로그인 비번이 아니라, appleid.apple.com 의"
  echo "   「앱 전용 비밀번호」 xxxx-xxxx-xxxx-xxxx 를 넣습니다)"
  echo ""
fi
echo "창을 닫으려면 Enter…"
read -r _
exit "${STATUS}"
