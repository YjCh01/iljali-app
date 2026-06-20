#!/usr/bin/env bash
# run_web.sh / run_qc.sh 공통 — naver_map_client_id.txt → flutter defines
# shellcheck disable=SC2034
NAVER_DEFINE=""
WEB_DEFINE="--web-define=NAVER_MAP_NCP_KEY=unset"

_naver_read_id() {
  NAVER_ID=""
  if [[ -f "naver_map_client_id.txt" ]]; then
    NAVER_ID="$(head -n 1 naver_map_client_id.txt | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi
}

_naver_valid_id() {
  [[ -n "${NAVER_ID:-}" ]] || return 1
  [[ "${NAVER_ID}" != "PASTE_CLIENT_ID_HERE" ]] || return 1
  [[ "${NAVER_ID}" != "YOUR_NAVER_MAP_CLIENT_ID" ]] || return 1
  return 0
}

naver_sync_flutter_defines() {
  _naver_read_id
  if ! _naver_valid_id; then
    echo "[경고] naver_map_client_id.txt 없음 → mock 지도 (실지도 X)"
    NAVER_DEFINE=""
    WEB_DEFINE="--web-define=NAVER_MAP_NCP_KEY=unset"
    return 1
  fi
  echo "[OK] Naver Client ID: ${NAVER_ID:0:4}****"
  mkdir -p web
  cp -f "naver_map_client_id.txt" "web/naver_map_client_id.txt"
  NAVER_DEFINE="--dart-define=NAVER_MAP_CLIENT_ID=${NAVER_ID}"
  WEB_DEFINE="--web-define=NAVER_MAP_NCP_KEY=${NAVER_ID}"
  return 0
}
