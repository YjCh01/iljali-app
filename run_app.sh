#!/usr/bin/env bash
# iOS/Android 앱 실행 — API는 NCP 기본 (로컬은 ILJARI_API_MODE=local)
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

API_PORT=8000
DEVICE="${1:-}"

free_port() {
  local pids
  pids="$(lsof -ti :"${1}" 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    echo "[${1} 포트] 이전 API 정리..."
    # shellcheck disable=SC2086
    kill -9 ${pids} 2>/dev/null || true
    sleep 1
  fi
}

echo
echo "========================================"
echo "  iljari 앱 실행 (iOS / Android)"
echo "========================================"
echo

if iljari_use_local_api; then
  free_port "${API_PORT}"
  if [[ ! -f server/.env ]]; then
    cp -f server/.env.example server/.env
  fi
fi

echo "[API] 준비..."
iljari_ensure_api_ready "$(iljari_resolve_compliance_api_url "${API_PORT}" "${DEVICE}")" "${API_PORT}"

API_URL="$(iljari_resolve_compliance_api_url "${API_PORT}" "${DEVICE}")"
iljari_print_api_banner "${API_URL}"

naver_sync_flutter_defines || true

flutter pub get

RUN_ARGS=(
  --dart-define="COMPLIANCE_API_URL=${API_URL}"
  --dart-define="ADMIN_API_KEY=$(iljari_resolve_admin_api_key)"
)
if [[ -n "${NAVER_DEFINE}" ]]; then
  # shellcheck disable=SC2206
  RUN_ARGS+=(${NAVER_DEFINE})
fi

if [[ -n "${DEVICE}" ]]; then
  echo "[실행] flutter run -d ${DEVICE}"
  # shellcheck disable=SC2068
  flutter run -d "${DEVICE}" "${RUN_ARGS[@]}"
else
  echo "[실행] flutter run (연결된 기기 선택)"
  echo "  iOS 시뮬레이터: ./run_app.sh ios"
  echo "  Android 에뮬:   ./run_app.sh emulator"
  # shellcheck disable=SC2068
  flutter run "${RUN_ARGS[@]}"
fi
