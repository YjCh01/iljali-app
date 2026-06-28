#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

WEB_PORT=8081
API_PORT=8000
API_URL="$(iljari_resolve_compliance_api_url "${API_PORT}")"
ADMIN_KEY="$(iljari_resolve_admin_api_key)"

echo
echo "========================================"
echo "  iljari Admin (NCP API + Chrome)"
iljari_print_api_banner "${API_URL}"
echo "  Admin : http://localhost:${WEB_PORT}/#/admin"
echo "========================================"
echo

free_port() {
  local pids
  pids="$(lsof -ti :"$1" 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    kill -9 ${pids} 2>/dev/null || true
    sleep 1
  fi
}

free_port "${WEB_PORT}"
if iljari_use_local_api && [[ ! -f server/.env ]]; then
  cp -f server/.env.example server/.env
fi

echo "[1/3] API 준비..."
iljari_ensure_api_ready "${API_URL}" "${API_PORT}"
iljari_wait_api_admin_stats "${API_URL}" "${ADMIN_KEY}" 90
iljari_admin_ensure_sample_jobs "${API_URL}" "${ADMIN_KEY}" || true

echo "[2/3] flutter pub get..."
flutter pub get

naver_sync_flutter_defines || true

echo "[3/3] Chrome Admin console..."
# shellcheck disable=SC2086
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=ADMIN_ENTRY=true \
  --dart-define=COMPLIANCE_API_URL="${API_URL}" \
  --dart-define=QC_MODE=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}
