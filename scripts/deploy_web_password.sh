#!/usr/bin/env bash
# SSH 키 없이(비밀번호) 웹 빌드 + 업로드 안내 — seeker 기본
# Usage: ./scripts/deploy_web_password.sh [site|seeker|web|corporate|admin|qc]
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
  WEB_LABEL="${BASE}/"
else
  WEB_LABEL="${BASE}/${VARIANT}/"
fi

echo ""
echo "========================================"
echo "  수동 Web 배포 (${VARIANT})"
echo "  API: $(iljari_resolve_compliance_api_url)"
echo "  Web: ${WEB_LABEL}"
echo "========================================"
echo ""

echo "[1/3] Flutter web 빌드 (10~15분)..."
./scripts/build_web_ncp.sh "${VARIANT}"

echo "[2/3] tar 생성..."
tar -czf "${TAR}" -C "build/web-deploy/${VARIANT}" .
ls -lh "${TAR}"

echo ""
echo "========================================"
echo "  [3/3] 아래를 순서대로 (비밀번호 입력)"
echo "========================================"
echo ""
echo "① 파일 업로드 (맥):"
echo ""
if [[ -f "${KEY}" ]]; then
  echo "scp -i \"${KEY}\" \"${TAR}\" ${TARGET}:/tmp/"
else
  echo "scp \"${TAR}\" ${TARGET}:/tmp/"
fi
echo ""
echo "② 서버 접속:"
echo ""
if [[ -f "${KEY}" ]]; then
  echo "ssh -i \"${KEY}\" ${TARGET}"
else
  echo "ssh ${TARGET}"
fi
echo ""
echo "③ 서버 안에서 (root@iljari-api-01 프롬프트):"
echo ""
if [[ "${VARIANT}" == "site" ]]; then
  SERVER_STEPS="mkdir -p ${WEB_DIR}
tar -xzf /tmp/iljari-web-${VARIANT}.tar.gz -C ${WEB_DIR}
bash /opt/iljari/server/scripts/finish_site_on_server.sh /tmp/iljari-web-${VARIANT}.tar.gz"
else
  SERVER_STEPS="mkdir -p ${WEB_DIR}/${VARIANT}
tar -xzf /tmp/iljari-web-${VARIANT}.tar.gz -C ${WEB_DIR}/${VARIANT}
bash /opt/iljari/server/scripts/setup_web_on_server.sh"
fi
echo "${SERVER_STEPS}"
echo "exit"
echo ""
echo "④ 맥 브라우저:"
echo "   ${WEB_LABEL}"
echo ""
read -r -p "① scp 끝나면 Enter (브라우저 열기)…" _
if [[ "$(uname)" == "Darwin" ]]; then
  open "${WEB_LABEL}"
fi
