#!/usr/bin/env bash
# NCP에 Flutter web 빌드 업로드 + nginx(web) 재기동
# Usage: ./scripts/deploy_web_ncp.sh [web|seeker|corporate|admin|qc]
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh

VARIANT="${1:-web}"
SSH_KEY="${ILJARI_SSH_KEY}"
SSH_TARGET="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
REMOTE_WEB="${ILJARI_REMOTE_WEB_DIR}"
REMOTE_SERVER="${ILJARI_SERVER_DIR_REMOTE}"
ARTIFACT="${ILJARI_ROOT}/build/web-deploy/${VARIANT}"

if [[ ! -f "${SSH_KEY}" ]]; then
  echo "ERROR: SSH key not found: ${SSH_KEY}"
  exit 1
fi

iljari_ssh_preflight "${VARIANT}" || exit 1
iljari_web_port_preflight || true

./scripts/build_web_ncp.sh "${VARIANT}"

REMOTE_SUBDIR="${VARIANT}"
if [[ "${VARIANT}" == "site" ]]; then
  REMOTE_SUBDIR=""
  REMOTE_PATH="${REMOTE_WEB}"
else
  REMOTE_PATH="${REMOTE_WEB}/${VARIANT}"
fi

echo "[deploy] ${VARIANT} → ${SSH_TARGET}:${REMOTE_PATH}/"
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_TARGET}" \
  "mkdir -p '${REMOTE_PATH}' '${REMOTE_SERVER}/nginx'"

# nginx + compose 동기화
scp -i "${SSH_KEY}" -q \
  "${ILJARI_ROOT}/server/docker-compose.yml" \
  "${ILJARI_ROOT}/server/nginx/"*.conf \
  "${ILJARI_ROOT}/server/scripts/setup_ssl_on_server.sh" \
  "${SSH_TARGET}:${REMOTE_SERVER}/"
ssh -i "${SSH_KEY}" "${SSH_TARGET}" \
  "mkdir -p '${REMOTE_SERVER}/nginx' '${REMOTE_SERVER}/scripts' && \
   mv '${REMOTE_SERVER}/'*.conf '${REMOTE_SERVER}/nginx/' 2>/dev/null || true && \
   mv '${REMOTE_SERVER}/setup_ssl_on_server.sh' '${REMOTE_SERVER}/scripts/' 2>/dev/null || true && \
   chmod +x '${REMOTE_SERVER}/scripts/'*.sh"

rsync -az --delete -e "ssh -i '${SSH_KEY}'" \
  "${ARTIFACT}/" \
  "${SSH_TARGET}:${REMOTE_PATH}/"

echo "[deploy] docker compose + SSL..."
ssh -i "${SSH_KEY}" "${SSH_TARGET}" \
  "cd '${REMOTE_SERVER}' && ILJARI_WEB_HOST_DIR='${REMOTE_WEB}' bash scripts/setup_ssl_on_server.sh"

if [[ "${VARIANT}" == "site" ]]; then
  PUBLIC_URL="$(iljari_resolve_web_base_url)/"
else
  PUBLIC_URL="$(iljari_resolve_web_base_url)/${VARIANT}/"
fi
echo "[deploy] done → ${PUBLIC_URL}"
