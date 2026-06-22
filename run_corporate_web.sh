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
ADMIN_KEY=qc-admin-dev-key
API_URL="http://localhost:${API_PORT}"

echo
echo "========================================"
echo "  iljari Corporate Web QC (900px+ 우측 탭)"
echo "  Dev login: corp-alpha@iljari.test"
echo "  API : ${API_URL}"
echo "  App : http://localhost:${WEB_PORT}"
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
free_port "${API_PORT}"

if [[ ! -f server/.env ]]; then
  cp -f server/.env.example server/.env
fi

iljari_ensure_server_env
iljari_start_api_server "${API_PORT}"
sleep 2

flutter pub get
naver_sync_flutter_defines || true

# shellcheck disable=SC2086
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=COMPLIANCE_API_URL="${API_URL}" \
  --dart-define=QC_MODE=false \
  --dart-define=CORPORATE_WEB_QC=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}
