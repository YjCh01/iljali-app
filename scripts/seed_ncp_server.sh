#!/usr/bin/env bash
# NCP 서버 Docker 안에서 QC 시드 (로컬 DB 시드 대신)
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

SEEKERS="${ILJARI_QC_SEEKERS:-100}"
SSH_KEY="${ILJARI_SSH_KEY}"
SSH_TARGET="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
REMOTE_DIR="${ILJARI_SERVER_DIR_REMOTE}"

if [[ ! -f "${SSH_KEY}" ]]; then
  echo "ERROR: SSH key not found: ${SSH_KEY}"
  echo "  Set ILJARI_SSH_KEY in scripts/remote_api.env"
  exit 1
fi

echo "[seed] NCP ${SSH_TARGET}:${REMOTE_DIR}"
echo "[seed] seekers=${SEEKERS} visual-scenario"

ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_TARGET}" \
  "cd '${REMOTE_DIR}' && docker compose exec -T api python scripts/seed_qc.py \
    --seekers ${SEEKERS} \
    --jobs fixtures/jobs.example.json \
    --wallet-brn 1000000001 \
    --wallet-credits 30 \
    --visual-scenario"

echo "[seed] done — check ${ILJARI_REMOTE_API_URL}/health"
