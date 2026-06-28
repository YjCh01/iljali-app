#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

WEB_PORT=8082
API_PORT=8000
API_URL="$(iljari_resolve_compliance_api_url "${API_PORT}")"
ADMIN_KEY="$(iljari_resolve_admin_api_key)"

echo
echo "========================================"
echo "  iljari 개인회원 Web (900px+ 우측 탭)"
echo "  Dev login: seeker-0001@qc.iljari.co.kr"
echo "  Pass     : QcTest1234!"
iljari_print_api_banner "${API_URL}"
echo "  App : http://localhost:${WEB_PORT}"
echo "  Tip : Chrome 창 너비 1200px+ 권장"
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
if iljari_use_local_api; then
  free_port "${API_PORT}"
  if [[ ! -f server/.env ]]; then
    cp -f server/.env.example server/.env
  fi
fi

echo "[1/3] API 준비..."
if iljari_use_local_api; then
  iljari_ensure_server_env
  (
    cd "${ILJARI_SERVER_DIR}"
    "${ILJARI_SERVER_PYTHON}" -m uvicorn app.main:app --host 127.0.0.1 --port "${API_PORT}" &
    API_PID=$!
    sleep 3
    "${ILJARI_SERVER_PYTHON}" scripts/seed_qc.py --seekers 100 --jobs fixtures/jobs.example.json --visual-scenario || true
    kill "${API_PID}" 2>/dev/null || true
  )
else
  echo "      데이터 없으면: ./scripts/seed_ncp_server.sh"
fi
iljari_ensure_api_ready "${API_URL}" "${API_PORT}"

flutter pub get
naver_sync_flutter_defines || true

echo "[3/3] Chrome seeker web..."
# shellcheck disable=SC2086
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=COMPLIANCE_API_URL="${API_URL}" \
  --dart-define=QC_MODE=true \
  --dart-define=INDIVIDUAL_ENTRY=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}
