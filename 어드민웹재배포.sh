#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/api_target.sh
source scripts/api_target.sh
chmod +x scripts/deploy_web_variant.sh

echo "========================================"
echo "  어드민 웹만 재배포"
echo "  (서버 키 ↔ 웹 키 불일치 시)"
echo "========================================"
echo ""

KEY_FILE="${HOME}/Projects Keys/iljari app/iljari-admin-api-key.txt"
if [[ ! -f "${KEY_FILE}" ]]; then
  echo "❌ 키 파일 없음: ${KEY_FILE}"
  echo "   먼저 도구_어드민보안강화.command 를 실행하세요."
  read -r -p "Enter…" _
  exit 1
fi

export ADMIN_API_KEY="$(head -n 1 "${KEY_FILE}" | tr -d '[:space:]')"
echo "맥에 저장된 어드민 키로 admin 웹 빌드·배포합니다."
echo "(root SSH 비밀번호 필요할 수 있음)"
echo ""

./scripts/deploy_web_variant.sh admin

echo ""
echo "완료 후 https://iljari.app/admin/ 새로고침"
echo "「API 연결됨」+ 대시보드 숫자 나오면 성공"
read -r -p "Enter…" _
