#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"

WEB_PORT=8081
API_PORT=8000
ADMIN_KEY=qc-admin-dev-key

echo
echo "========================================"
echo "  iljari Admin (server + Chrome)"
echo "  API   : http://127.0.0.1:${API_PORT}"
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

if [[ ! -f server/.env ]]; then
  cp -f server/.env.example server/.env
fi

if ! lsof -ti :"${API_PORT}" >/dev/null 2>&1; then
  echo "[1/3] starting API on ${API_PORT}..."
  (
    cd server
    uvicorn app.main:app --host 127.0.0.1 --port "${API_PORT}" &
  )
  sleep 2
else
  echo "[1/3] API already running on ${API_PORT}"
fi

echo "[2/3] flutter pub get..."
flutter pub get

naver_sync_flutter_defines || true

echo "[3/3] Chrome Admin console..."
# shellcheck disable=SC2086
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=ADMIN_ENTRY=true \
  --dart-define=COMPLIANCE_API_URL="http://127.0.0.1:${API_PORT}" \
  --dart-define=QC_MODE=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}
