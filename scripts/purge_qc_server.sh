#!/usr/bin/env bash
# NCP 프로덕션 DB — QC 시드 데이터 삭제
# 사전 조건: ./scripts/deploy_prod_all.sh --api-only (qc_data_purge_service 포함)
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

echo "[purge] NCP ${SSH_TARGET}:${REMOTE_DIR} dry_run=${DRY_RUN_PY}"
echo "[purge] API에 purge 모듈 없으면 먼저: ./scripts/deploy_prod_all.sh --api-only"

# scripts/ 는 구 이미지에 없을 수 있어 app 서비스 모듈로 직접 실행
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_TARGET}" \
  "cd '${REMOTE_DIR}' && docker compose exec -T api python -c \"
from app.database import SessionLocal
from app.services.qc_data_purge_service import purge_qc_data
import json
db = SessionLocal()
try:
    print(json.dumps(purge_qc_data(db, dry_run=${DRY_RUN_PY}), ensure_ascii=False))
finally:
    db.close()
\""

echo "[purge] done"
