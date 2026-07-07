#!/usr/bin/env bash
set -euo pipefail

echo "========================================"
echo "  Google OAuth 프로덕션 전환 안내"
echo "========================================"
echo ""
echo "【왜 필요한가】"
echo "  테스트 모드면 승인된 100명만 로그인 가능"
echo "  프로덕션 전환 후 일반 구글 계정 모두 로그인"
echo ""
echo "【순서】"
echo "  1. https://console.cloud.google.com/apis/credentials"
echo "  2. OAuth 2.0 클라이언트 ID (일자리 웹) 선택"
echo "  3. 승인된 리디렉션 URI 확인:"
echo "     https://api.iljari.app/v1/auth/social/google/callback"
echo "  4. https://console.cloud.google.com/apis/credentials/consent"
echo "     → OAuth 동의 화면 → 「앱 게시」 또는 「프로덕션으로 전환」"
echo "  5. 검증 필요 시: 개인정보처리방침 URL"
echo "     https://iljari.app"
echo ""
echo "【서버 키 변경 시】"
echo "  도구_구글로그인키_서버등록.command"
echo ""

if command -v open >/dev/null 2>&1; then
  read -r -p "Google Cloud Console 열까요? (y/N): " ans
  if [[ "${ans}" =~ ^[Yy]$ ]]; then
    open "https://console.cloud.google.com/apis/credentials/consent"
  fi
fi

read -r -p "Enter…" _
