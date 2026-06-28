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
echo "  iljari Corporate Web QC (900px+ 우측 탭)"
echo "  Dev login: corp-alpha@test.iljari.co.kr / Test1234!"
iljari_print_api_banner "${API_URL}"
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
if iljari_use_local_api && [[ ! -f server/.env ]]; then
  cp -f server/.env.example server/.env
fi

echo "[API] 준비..."
iljari_ensure_api_ready "${API_URL}" "${API_PORT}"

flutter pub get
naver_sync_flutter_defines || true

# shellcheck disable=SC2086
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=COMPLIANCE_API_URL="${API_URL}" \
  --dart-define=QC_MODE=false \
  --dart-define=CORPORATE_WEB_QC=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}
