#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"
# shellcheck source=scripts/server_dev.sh
source "scripts/server_dev.sh"

WEB_PORT=8080
API_PORT=8000
API_URL="$(iljari_resolve_compliance_api_url "${API_PORT}")"

echo
echo "========================================"
echo "  iljari 웹 실행 (Chrome)"
echo "  App : http://localhost:${WEB_PORT}"
iljari_print_api_banner "${API_URL}"
echo "========================================"
echo

free_port() {
  local pids
  pids="$(lsof -ti :"${1}" 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    echo "[${1} 포트] 이전 실행 정리 중..."
    # shellcheck disable=SC2086
    kill -9 ${pids} 2>/dev/null || true
    sleep 2
  fi
}

read_naver_id() { _naver_read_id; }
validate_naver_id() { _naver_valid_id; }

free_port "${WEB_PORT}"
if iljari_use_local_api; then
  free_port "${API_PORT}"
  if [[ ! -f server/.env ]]; then
    cp -f server/.env.example server/.env
  fi
fi

echo "[API] 준비..."
iljari_ensure_api_ready "${API_URL}" "${API_PORT}"

NAVER_DEFINE=""
WEB_DEFINE="--web-define=NAVER_MAP_NCP_KEY=unset"

read_naver_id
if ! validate_naver_id; then
  echo "[안내] 네이버 Client ID 설정"
  echo "  NCP - Dynamic Map + Web URL:"
  echo "    http://localhost:${WEB_PORT}"
  echo "    http://localhost"
  echo
  if [[ ! -f "naver_map_client_id.txt" ]]; then
    cp -f "naver_map_client_id.txt.example" "naver_map_client_id.txt"
  fi
  if [[ "$(uname)" == "Darwin" ]]; then
    open -e "naver_map_client_id.txt"
  else
    "${EDITOR:-nano}" "naver_map_client_id.txt"
  fi
  echo "  저장 후 Enter..."
  read -r _
  read_naver_id
  if ! validate_naver_id; then
    echo "[경고] Client ID 없음 - mock 지도"
    sleep 4
  fi
fi

if validate_naver_id; then
  naver_sync_flutter_defines || true
  echo
fi

echo "1. flutter pub get ..."
flutter pub get

echo
echo "2. Chrome 실행..."
# shellcheck disable=SC2086
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=COMPLIANCE_API_URL="${API_URL}" \
  --dart-define=ADMIN_API_KEY="$(iljari_resolve_admin_api_key)" \
  ${WEB_DEFINE} ${NAVER_DEFINE}
RUN_EXIT=$?

if [[ "${RUN_EXIT}" -ne 0 ]]; then
  echo
  echo "[실패] 실행이 끝났습니다 (코드 ${RUN_EXIT})."
  echo "  Chrome 창을 모두 닫고 ./run_web.sh 를 다시 실행해 보세요."
fi

exit "${RUN_EXIT}"
