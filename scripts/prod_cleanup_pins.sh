#!/usr/bin/env bash
# 프로덕션 API — QC purge + 어드민 증정 회수 (dry-run 기본)
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/api_target.sh
source "scripts/api_target.sh"

DRY_RUN=1
ACTION="all"
for arg in "$@"; do
  case "${arg}" in
    --dry-run) DRY_RUN=1 ;;
    --yes) DRY_RUN=0 ;;
    --qc-only) ACTION="qc" ;;
    --revoke-only) ACTION="revoke" ;;
  esac
done

API="$(iljari_resolve_compliance_api_url)"
KEY="$(iljari_resolve_admin_api_key)"
QS=""
if [[ "${DRY_RUN}" == 1 ]]; then
  QS="?dry_run=true"
fi

call_api() {
  local path="$1"
  curl -skf -H "X-Admin-Api-Key: ${KEY}" "${API}${path}${QS}"
}

echo "[ops] API=${API} dry_run=${DRY_RUN} action=${ACTION}"

if [[ "${ACTION}" == "all" || "${ACTION}" == "qc" ]]; then
  echo "[ops] purge/qc"
  call_api "/v1/admin/ops/purge/qc" | python3 -m json.tool
fi

if [[ "${ACTION}" == "all" || "${ACTION}" == "revoke" ]]; then
  echo "[ops] wallet/revoke-admin-grants"
  call_api "/v1/admin/ops/wallet/revoke-admin-grants" | python3 -m json.tool
fi

echo "[ops] done"
