#!/usr/bin/env bash
# SSH 키가 안 될 때 — 빌드 후 tar 만들고 scp 안내 (비밀번호 업로드)
# Usage: ./scripts/pack_web_upload.sh [web|seeker|corporate|admin|qc]
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh

VARIANT="${1:-seeker}"
TAR="/tmp/iljari-web-${VARIANT}.tar.gz"
REMOTE="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
WEB_DIR="${ILJARI_REMOTE_WEB_DIR}"

./scripts/build_web_ncp.sh "${VARIANT}"

tar -czf "${TAR}" -C "build/web-deploy/${VARIANT}" .

echo ""
echo "========================================"
echo "  수동 업로드 (${VARIANT})"
echo "========================================"
echo ""
echo "1) 서버에 올리기 (비밀번호 입력):"
echo "   scp \"${TAR}\" ${REMOTE}:/tmp/"
echo ""
echo "2) 서버 SSH에서:"
echo "   mkdir -p ${WEB_DIR}/${VARIANT}"
echo "   tar -xzf /tmp/iljari-web-${VARIANT}.tar.gz -C ${WEB_DIR}/${VARIANT}"
echo "   bash ${ILJARI_SERVER_DIR_REMOTE}/scripts/setup_web_on_server.sh"
echo ""
echo "3) 브라우저:"
echo "   $(iljari_resolve_web_base_url)/${VARIANT}/"
echo "========================================"
