#!/usr/bin/env bash
# NCP 프로덕션 — 유령핀·유령노선·공고·셔틀 노선 전체 삭제
# 사용: ./scripts/purge_map_content_server.sh --dry-run
#       ./scripts/purge_map_content_server.sh --yes
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

DRY_RUN=1
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

DRY_RUN_PY="True"
if [[ "${DRY_RUN}" == 0 ]]; then
  DRY_RUN_PY="False"
fi

echo "[purge-map] NCP ${SSH_TARGET}:${REMOTE_DIR} dry_run=${DRY_RUN_PY}"

# 서버에 신규 모듈이 없을 수 있어 인라인으로 동일 삭제를 수행
ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=accept-new "${SSH_TARGET}" \
  "cd '${REMOTE_DIR}' && docker compose exec -T api python -c \"
from sqlalchemy import delete, func, select
from app.database import SessionLocal
from app.job_sync_models import ChatMessageRow, JobApplicationRow, JobPostRow
from app.qc_models import ClosedGhostPinRow, ClosedGhostRouteRow, JobPostEntitlementRow
from app.shuttle_models import (
    CommuteRouteRow,
    SeekerShuttlePreferenceRow,
    ShuttleRouteShareConsentRow,
)
import json

db = SessionLocal()
try:
    counts = {
        'chat_messages': db.scalar(select(func.count()).select_from(ChatMessageRow)) or 0,
        'job_applications': db.scalar(select(func.count()).select_from(JobApplicationRow)) or 0,
        'job_post_entitlements': db.scalar(select(func.count()).select_from(JobPostEntitlementRow)) or 0,
        'job_posts': db.scalar(select(func.count()).select_from(JobPostRow)) or 0,
        'closed_ghost_routes': db.scalar(select(func.count()).select_from(ClosedGhostRouteRow)) or 0,
        'closed_ghost_pins': db.scalar(select(func.count()).select_from(ClosedGhostPinRow)) or 0,
        'seeker_shuttle_preferences': db.scalar(select(func.count()).select_from(SeekerShuttlePreferenceRow)) or 0,
        'shuttle_route_share_consents': db.scalar(select(func.count()).select_from(ShuttleRouteShareConsentRow)) or 0,
        'commute_routes': db.scalar(select(func.count()).select_from(CommuteRouteRow)) or 0,
    }
    if ${DRY_RUN_PY}:
        print(json.dumps({'dry_run': True, 'deleted': counts}, ensure_ascii=False))
    else:
        db.execute(delete(ChatMessageRow))
        db.execute(delete(JobApplicationRow))
        db.execute(delete(JobPostEntitlementRow))
        db.execute(delete(JobPostRow))
        db.execute(delete(ClosedGhostRouteRow))
        db.execute(delete(ClosedGhostPinRow))
        db.execute(delete(SeekerShuttlePreferenceRow))
        db.execute(delete(ShuttleRouteShareConsentRow))
        db.execute(delete(CommuteRouteRow))
        db.commit()
        print(json.dumps({'dry_run': False, 'deleted': counts}, ensure_ascii=False))
finally:
    db.close()
\""

echo "[purge-map] done"
