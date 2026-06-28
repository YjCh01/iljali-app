#!/usr/bin/env bash
# 비밀번호 SSH로 빌드·업로드·서버설정·브라우저까지 한 번에
# Usage: ./scripts/deploy_one_shot.sh [site|seeker|web|corporate|admin|qc]
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh

VARIANT="${1:-site}"
KEY="${ILJARI_SSH_KEY}"
TARGET="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
WEB_DIR="${ILJARI_REMOTE_WEB_DIR}"
TAR="/tmp/iljari-web-${VARIANT}.tar.gz"
BASE="$(iljari_resolve_web_base_url)"
if [[ "${VARIANT}" == "site" ]]; then
  PUBLIC="${BASE}/"
else
  PUBLIC="${BASE}/${VARIANT}/"
fi

SSH_OPTS=(-o ConnectTimeout=20 -o PreferredAuthentications=password,publickey -o PubkeyAuthentication=yes)
[[ -f "${KEY}" ]] && SSH_OPTS+=(-i "${KEY}")

clear
echo ""
echo "========================================"
echo "  일자리 — 한 번에 배포 (${VARIANT})"
echo "  API : $(iljari_resolve_compliance_api_url)"
echo "  Web : ${PUBLIC}"
echo "========================================"
echo ""
echo "NCP 관리자 비밀번호를 최대 2번 입력합니다."
echo "(비밀번호는 화면에 안 보여도 정상)"
echo ""

# API만 먼저 확인
if ! iljari_curl_api "$(iljari_resolve_compliance_api_url)/health" >/dev/null 2>&1; then
  echo "WARN: API health 실패 — 그래도 웹 배포는 계속합니다."
fi

if [[ ! -f "${TAR}" ]] || [[ "${ILJARI_FORCE_REBUILD:-}" == "1" ]]; then
  echo "[1/4] Flutter web 빌드 (이미 했으면 잠시)..."
  ./scripts/build_web_ncp.sh "${VARIANT}"
  tar -czf "${TAR}" -C "build/web-deploy/${VARIANT}" .
else
  echo "[1/4] 기존 tar 사용 — ${TAR}"
fi

echo ""
echo "[2/4] 서버로 파일 보내는 중... (비밀번호 ①)"
scp "${SSH_OPTS[@]}" "${TAR}" "${TARGET}:/tmp/iljari-web-${VARIANT}.tar.gz"

echo ""
echo "[3/4] 서버 설정 중... (비밀번호 ②, 같으면 또 입력)"
ssh "${SSH_OPTS[@]}" "${TARGET}" bash -s -- "${VARIANT}" "${WEB_DIR}" "${TAR}" <<'REMOTE'
set -euo pipefail
VARIANT="$1"
WEB_DIR="$2"
TAR="$3"
if [[ "${VARIANT}" == "site" ]]; then
  mkdir -p "${WEB_DIR}"
  tar -xzf "${TAR}" -C "${WEB_DIR}"
else
  mkdir -p "${WEB_DIR}/${VARIANT}"
  tar -xzf "${TAR}" -C "${WEB_DIR}/${VARIANT}"
fi
if [[ -f /opt/iljari/server/scripts/setup_web_on_server.sh ]]; then
  bash /opt/iljari/server/scripts/setup_web_on_server.sh
else
  cd /opt/iljari/server
  export ILJARI_WEB_HOST_DIR="${WEB_DIR}"
  docker compose up -d --build edge api
fi
echo "[server] 배포 완료 — ${VARIANT}"
REMOTE

echo ""
echo "[4/4] 브라우저 열기: ${PUBLIC}"
if [[ "$(uname)" == "Darwin" ]]; then
  open "${PUBLIC}"
fi

echo ""
echo "========================================"
echo "  완료!  ${PUBLIC}"
echo "  안 열리면 NCP ACG → TCP 80 확인"
echo "  지도: http://www.iljari.app 네이버 NCP URL 등록"
echo "========================================"
echo ""
read -r -p "Enter 키로 창 닫기…" _
