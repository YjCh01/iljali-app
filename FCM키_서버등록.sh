#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/set_fcm_on_server.sh

echo "========================================"
echo "  Firebase FCM → 서버 등록"
echo "========================================"
echo ""
echo "【준비】 Firebase Console → 프로젝트 설정 → 서비스 계정"
echo "  → 「새 비공개 키 생성」→ JSON 파일 다운로드"
echo ""
echo "JSON 파일 경로를 입력하세요 (드래그&드롭 후 Enter):"
read -r -p "> " JSON_PATH
JSON_PATH="${JSON_PATH//\'/}"
JSON_PATH="${JSON_PATH//\"/}"

if [[ -z "${JSON_PATH}" || ! -f "${JSON_PATH}" ]]; then
  echo "파일을 찾을 수 없습니다: ${JSON_PATH}"
  read -r -p "Enter…" _
  exit 1
fi

echo ""
echo "[진행] 서버 접속… (root 비밀번호)"
./scripts/set_fcm_on_server.sh "${JSON_PATH}"

echo ""
echo "앱에서 로그인 후 푸시 권한 허용 → 실기기 알림 1건 테스트"
read -r -p "Enter…" _
