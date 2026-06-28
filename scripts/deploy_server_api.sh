#!/usr/bin/env bash
# FastAPI 서버 코드 → NCP /opt/iljari/server + api 컨테이너 재빌드
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

TAR="/tmp/iljari-server-$(date +%s).tar.gz"
REMOTE_TAR="/tmp/iljari-server-deploy.tar.gz"
REMOTE_DIR="${ILJARI_SERVER_DIR_REMOTE:-/opt/iljari/server}"

echo "========================================"
echo "  API 서버 배포 → $(iljari_resolve_compliance_api_url)"
echo "========================================"

iljari_ssh_init

echo "[1/3] server tarball..."
iljari_tar_create "${TAR}" \
  --exclude='.venv' \
  --exclude='__pycache__' \
  --exclude='*.pyc' \
  --exclude='*.db' \
  --exclude='.env' \
  -C "${ILJARI_ROOT}/server" .

echo "[2/3] upload..."
iljari_ssh_upload "${REMOTE_TAR}" "${TAR}"

echo "[3/3] extract + docker rebuild..."
iljari_ssh_run bash -s <<REMOTE
set -euo pipefail
REMOTE_DIR="${REMOTE_DIR}"
REMOTE_TAR="${REMOTE_TAR}"
ENV_BAK="/tmp/iljari-server-env.bak"
if [[ -f "\${REMOTE_DIR}/.env" ]]; then
  cp "\${REMOTE_DIR}/.env" "\${ENV_BAK}"
fi
mkdir -p "\${REMOTE_DIR}"
if tar --warning=no-unknown-keyword -xzf "\${REMOTE_TAR}" -C "\${REMOTE_DIR}" 2>/dev/null; then
  :
else
  tar -xzf "\${REMOTE_TAR}" -C "\${REMOTE_DIR}"
fi
if [[ -f "\${ENV_BAK}" ]]; then
  cp "\${ENV_BAK}" "\${REMOTE_DIR}/.env"
fi
cd "\${REMOTE_DIR}"
export ILJARI_WEB_HOST_DIR="${ILJARI_REMOTE_WEB_DIR:-/opt/iljari/web}"
docker compose up -d --build api
docker compose up -d edge db 2>/dev/null || true
$(iljari_remote_api_wait_block)
echo "[server] API deploy OK"
REMOTE

rm -f "${TAR}"

iljari_verify_public_api_health "$(iljari_resolve_compliance_api_url)" 90
