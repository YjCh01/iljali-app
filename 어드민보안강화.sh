#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/api_target.sh
source scripts/api_target.sh
chmod +x scripts/set_admin_api_key_on_server.sh \
  scripts/set_admin_ip_allowlist_on_server.sh \
  scripts/sync_admin_nginx_to_server.sh \
  scripts/deploy_web_variant.sh

KEY_DIR="${HOME}/Projects Keys/iljari app"
KEY_FILE="${KEY_DIR}/iljari-admin-api-key.txt"

echo "========================================"
echo "  어드민 보안 강화 (일회 설정)"
echo "========================================"
echo ""
echo "이 도구가 하는 일:"
echo "  ① 새 어드민 비밀키 생성 (서버 + 맥에만 저장)"
echo "  ② /admin/ 주소 — 지정한 IP만 접속 허용"
echo "  ③ 어드민 웹 다시 배포 (새 키 반영)"
echo ""
echo "※ 일반 사용자(iljari.app)는 영향 없습니다."
echo "※ root SSH 비밀번호 1회 필요할 수 있습니다."
echo ""

echo "[1/5] 지금 이 맥의 공인 IP 확인 중..."
MY_IP="$(curl -sS -m 10 https://api.ipify.org 2>/dev/null || true)"
if [[ -z "${MY_IP}" ]]; then
  MY_IP="$(curl -sS -m 10 https://ifconfig.me 2>/dev/null || true)"
fi
if [[ -n "${MY_IP}" ]]; then
  echo "  → ${MY_IP}"
else
  echo "  → 자동 확인 실패 (나중에 수동 입력)"
fi
echo ""

echo "【IP 제한】 /admin/ 은 누가 열 수 있나요?"
echo "  y = 지금 이 맥 IP만 (${MY_IP:-?})"
echo "  n = IP 제한 안 함 (키만 교체)"
echo "  직접 입력 = 쉼표로 여러 IP (집, 사무실)"
echo ""
read -r -p "선택 (y/n/직접입력) [y]: " IP_CHOICE
IP_CHOICE="${IP_CHOICE:-y}"

IPS=()
case "${IP_CHOICE}" in
  n|N)
    IP_MODE="clear"
    ;;
  y|Y|"")
    if [[ -z "${MY_IP}" ]]; then
      read -r -p "공인 IP 직접 입력: " MY_IP
    fi
    IPS=("${MY_IP}")
    IP_MODE="set"
    ;;
  *)
    IFS=',' read -r -a IPS <<< "${IP_CHOICE}"
    IP_MODE="set"
    ;;
esac

echo ""
echo "[2/5] 새 어드민 비밀키 생성..."
NEW_KEY="$(openssl rand -hex 32)"
mkdir -p "${KEY_DIR}"
echo "${NEW_KEY}" > "${KEY_FILE}"
chmod 600 "${KEY_FILE}"
echo "  → 맥 저장: ${KEY_FILE}"
echo "  (채팅·Git에 올리지 마세요)"

echo ""
echo "[3/5] 서버에 새 키 등록..."
./scripts/set_admin_api_key_on_server.sh "${NEW_KEY}"

echo ""
echo "[4/5] /admin/ IP 제한 설정..."
if [[ "${IP_MODE}" == "clear" ]]; then
  ./scripts/set_admin_ip_allowlist_on_server.sh --clear
else
  ./scripts/set_admin_ip_allowlist_on_server.sh "${IPS[@]}"
fi

echo ""
echo "[5/5] 어드민 웹 재배포 (새 키 포함)..."
export ADMIN_API_KEY="${NEW_KEY}"
if ! ./scripts/deploy_web_variant.sh admin; then
  echo ""
  echo "⚠️  어드민 웹 배포가 실패했을 수 있습니다."
  echo "   서버 키는 이미 바뀌었으므로 → 도구_어드민웹재배포.command 실행"
  read -r -p "Enter…" _
  exit 1
fi

API_URL="$(iljari_resolve_compliance_api_url)"
echo ""
echo "========================================"
echo "  ✅ 어드민 보안 강화 완료"
echo "========================================"
echo ""
echo "  어드민 주소: https://iljari.app/admin/"
if [[ "${IP_MODE}" == "set" ]]; then
  echo "  허용 IP    : ${IPS[*]}"
  echo "  (다른 곳·핫스팟에서는 /admin/ 403 가능)"
else
  echo "  IP 제한    : 없음 (키만 교체됨)"
fi
echo ""
echo "  확인: 좌측에 「API 연결됨」이 보이면 성공"
echo ""
if [[ "$(uname)" == "Darwin" ]]; then
  read -r -p "브라우저에서 어드민 열까요? (y/N): " OPEN
  if [[ "${OPEN}" =~ ^[Yy]$ ]]; then
    open "https://iljari.app/admin/"
  fi
fi
read -r -p "Enter…" _
