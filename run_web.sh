#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"

WEB_PORT=8080

echo
echo "========================================"
echo "  iljari 웹 실행 (Chrome)"
echo "  주소: http://localhost:${WEB_PORT}"
echo "========================================"
echo

free_port() {
  local pids
  pids="$(lsof -ti :"${WEB_PORT}" 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    echo "[${WEB_PORT} 포트] 이전 실행 정리 중..."
    # shellcheck disable=SC2086
    kill -9 ${pids} 2>/dev/null || true
    sleep 2
  fi
}

read_naver_id() {
  NAVER_ID=""
  if [[ -f "naver_map_client_id.txt" ]]; then
    NAVER_ID="$(head -n 1 naver_map_client_id.txt | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi
}

validate_naver_id() {
  [[ -n "${NAVER_ID}" ]] || return 1
  [[ "${NAVER_ID}" != "PASTE_CLIENT_ID_HERE" ]] || return 1
  [[ "${NAVER_ID}" != "YOUR_NAVER_MAP_CLIENT_ID" ]] || return 1
  return 0
}

free_port

read_naver_id() { _naver_read_id; }
validate_naver_id() { _naver_valid_id; }

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
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" ${WEB_DEFINE} ${NAVER_DEFINE}
RUN_EXIT=$?

if [[ "${RUN_EXIT}" -ne 0 ]]; then
  echo
  echo "[실패] 실행이 끝났습니다 (코드 ${RUN_EXIT})."
  echo "  Chrome 창을 모두 닫고 ./run_web.sh 를 다시 실행해 보세요."
fi

exit "${RUN_EXIT}"
