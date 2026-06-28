#!/usr/bin/env bash
# 웹 variant 빌드 → NCP 배포 → URL 200 확인
# Usage: ./scripts/deploy_web_variant.sh site|corporate|admin|seeker|qc
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
source scripts/server_dev.sh
source scripts/iljari_ssh.sh

VARIANT="${1:?variant}"
TAR="/tmp/iljari-web-${VARIANT}.tar.gz"

if [[ "${VARIANT}" == "site" ]]; then
  PUBLIC="$(iljari_resolve_web_base_url)/"
else
  PUBLIC="$(iljari_resolve_web_base_url)/${VARIANT}/"
fi

echo "========================================"
echo "  배포: ${VARIANT}"
echo "  → ${PUBLIC}"
echo "========================================"

iljari_ssh_init

echo "[1/4] 빌드..."
./scripts/build_web_ncp.sh "${VARIANT}"

echo "[2/4] tar..."
COPYFILE_DISABLE=1 tar -czf "${TAR}" -C "build/web-deploy/${VARIANT}" .

echo "[3/4] 업로드..."
iljari_ssh_upload "${TAR}" "${TAR}"
iljari_ssh_upload /opt/iljari/server/scripts/deploy_variant_on_server.sh \
  "${ILJARI_ROOT}/server/scripts/deploy_variant_on_server.sh"
iljari_ssh_run "chmod +x /opt/iljari/server/scripts/deploy_variant_on_server.sh"
iljari_ssh_run "ILJARI_ADMIN_API_KEY='$(iljari_resolve_admin_api_key)' bash /opt/iljari/server/scripts/deploy_variant_on_server.sh ${VARIANT} ${TAR}"

echo "[4/4] 확인..."
sleep 2
CODE="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 20 "${PUBLIC}" 2>/dev/null || echo 0)"
if [[ ! "${CODE}" =~ ^[23] ]]; then
  echo "❌ ${PUBLIC} → HTTP ${CODE}"
  echo "   도구_사이트완료.command 로 SSL/nginx 점검"
  exit 1
fi
echo "✅ ${PUBLIC} → HTTP ${CODE}"
