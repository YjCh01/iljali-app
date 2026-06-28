#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

SEEKER_PORT=8082
CORP_PORT=8081
API_PORT=8000
API_URL="$(iljari_resolve_compliance_api_url "${API_PORT}")"
ADMIN_KEY="$(iljari_resolve_admin_api_key)"

echo
echo "========================================"
echo "  iljari Dual QC — 구직자 + 기업 동시 실행"
iljari_print_api_banner "${API_URL}"
echo "  구직자  : http://localhost:${SEEKER_PORT}"
echo "    QC 구직자 0001 / seeker-0001@qc.iljari.co.kr / QcTest1234!"
echo "  기업    : http://localhost:${CORP_PORT}"
echo "    테스트기업 알파 / corp-alpha@test.iljari.co.kr / Test1234!"
echo "  시나리오: 알파 공고(qc_post_real_001) + 0001 지원·채팅·출근"
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

free_port "${SEEKER_PORT}"
free_port "${CORP_PORT}"
if iljari_use_local_api; then
  free_port "${API_PORT}"
  if [[ ! -f server/.env ]]; then
    cp -f server/.env.example server/.env
  fi
fi

echo "[1/5] API 준비..."
if iljari_use_local_api; then
  echo "      local QC DB seed (알파 + 0001 시나리오)..."
  iljari_ensure_server_env
  (
    cd "${ILJARI_SERVER_DIR}"
    "${ILJARI_SERVER_PYTHON}" -m uvicorn app.main:app --host 127.0.0.1 --port "${API_PORT}" &
    API_PID=$!
    sleep 3
    "${ILJARI_SERVER_PYTHON}" scripts/seed_qc.py \
      --seekers 100 \
      --jobs fixtures/jobs.example.json \
      --wallet-brn 1000000001 \
      --wallet-credits 30 \
      --visual-scenario || true
    kill "${API_PID}" 2>/dev/null || true
  )
else
  echo "      데이터 없으면: ./scripts/seed_ncp_server.sh"
fi
iljari_ensure_api_ready "${API_URL}" "${API_PORT}"

echo "[2/5] flutter pub get..."
flutter pub get
naver_sync_flutter_defines || true

FLUTTER_BASE=(
  flutter run -d chrome --web-hostname=localhost
  --dart-define=COMPLIANCE_API_URL="${API_URL}"
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}"
  ${WEB_DEFINE} ${NAVER_DEFINE}
)

echo "[3/5] Chrome — 기업 (포트 ${CORP_PORT})..."
# shellcheck disable=SC2086
"${FLUTTER_BASE[@]}" --web-port="${CORP_PORT}" \
  --dart-define=QC_MODE=false \
  --dart-define=CORPORATE_WEB_QC=true &
CORP_PID=$!

echo "[4/5] Chrome — 구직자 (포트 ${SEEKER_PORT})..."
# shellcheck disable=SC2086
"${FLUTTER_BASE[@]}" --web-port="${SEEKER_PORT}" \
  --dart-define=QC_MODE=true \
  --dart-define=INDIVIDUAL_ENTRY=true

kill "${CORP_PID}" 2>/dev/null || true
