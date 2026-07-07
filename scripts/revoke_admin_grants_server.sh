#!/usr/bin/env bash
# NCP 프로덕션 DB — 어드민 증정 지갑·entitlement 회수
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

DRY_RUN=0
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=1 ;;
    --yes) DRY_RUN=0 ;;
  esac
done

SSH_KEY="${ILJARI_SSH_KEY}"
SSH_TARGET="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
REMOTE_DIR="${ILJARI_SERVER_DIR_REMOTE}"

if [[ ! -f "${SSH_KEY}" ]]; then
  echo "ERROR: SSH key not found: ${SSH_KEY}"
  exit 1
fi

DRY_RUN_PY="False"
if [[ "${DRY_RUN}" == 1 ]]; then
  DRY_RUN_PY="True"
fi

echo "[revoke] NCP ${SSH_TARGET}:${REMOTE_DIR} dry_run=${DRY_RUN_PY}"

ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_TARGET}" \
  "cd '${REMOTE_DIR}' && docker compose exec -T api python -c \"
from app.database import SessionLocal
from app.services.admin_grant_revoke_service import revoke_admin_grants
import json
db = SessionLocal()
try:
    print(json.dumps(revoke_admin_grants(db, dry_run=${DRY_RUN_PY}), ensure_ascii=False))
finally:
    db.close()
\""

echo "[revoke] done"
