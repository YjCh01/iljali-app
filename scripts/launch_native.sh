#!/usr/bin/env bash
# iOS / Android — 실서비스=api.iljari.app · 개발=맥 로컬 API
# Usage: ./scripts/launch_native.sh <android|ios> <seeker|corporate|admin> <server|local>
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
source scripts/naver_flutter_defines.sh
source scripts/server_dev.sh

PLATFORM="${1:?android|ios}"
ROLE="${2:?seeker|corporate|admin}"
ENV="${3:?server|local}"

export ILJARI_ENV="${ENV}"

API_PORT=8000

resolve_device() {
  case "${PLATFORM}" in
    android)
      if flutter devices 2>/dev/null | grep -qE '• android •'; then
        flutter devices 2>/dev/null | grep '• android •' | head -1 | awk -F'•' '{print $2}' | tr -d ' '
      elif flutter devices 2>/dev/null | grep -qi emulator; then
        flutter devices 2>/dev/null | grep -i emulator | head -1 | awk -F'•' '{print $2}' | tr -d ' '
      else
        echo "android"
      fi
      ;;
    ios)
      open -a Simulator 2>/dev/null || true
      sleep 2
      if flutter devices 2>/dev/null | grep -qi iphone; then
        flutter devices 2>/dev/null | grep -i iphone | head -1 | awk -F'•' '{print $2}' | tr -d ' '
      else
        echo "ios"
      fi
      ;;
    *) echo "ERROR: platform ${PLATFORM}"; exit 1 ;;
  esac
}

free_port() {
  local pids
  pids="$(lsof -ti :"${1}" 2>/dev/null || true)"
  [[ -n "${pids}" ]] && kill -9 ${pids} 2>/dev/null || true
  sleep 1
}

clear
echo "========================================"
iljari_print_env_banner
echo "  앱: ${PLATFORM} · ${ROLE} · ${ENV}"
echo "========================================"
echo ""

if iljari_is_local; then
  free_port "${API_PORT}"
  [[ ! -f server/.env ]] && cp -f server/.env.example server/.env
fi

DEVICE="$(resolve_device)"
echo "  device: ${DEVICE}"

iljari_ensure_api_ready "$(iljari_resolve_compliance_api_url "${API_PORT}" "${DEVICE}")" "${API_PORT}"
API_URL="$(iljari_resolve_compliance_api_url "${API_PORT}" "${DEVICE}")"
echo "  API: ${API_URL}"
echo ""

naver_sync_flutter_defines || true
flutter pub get

RUN_ARGS=(
  --dart-define="COMPLIANCE_API_URL=${API_URL}"
  --dart-define="ADMIN_API_KEY=$(iljari_resolve_admin_api_key)"
)

case "${ROLE}" in
  seeker) RUN_ARGS+=(--dart-define=INDIVIDUAL_ENTRY=true --dart-define=QC_MODE=false) ;;
  corporate) RUN_ARGS+=(--dart-define=CORPORATE_WEB_QC=true --dart-define=QC_MODE=false) ;;
  admin) RUN_ARGS+=(--dart-define=ADMIN_ENTRY=true --dart-define=QC_MODE=true) ;;
esac

[[ -n "${NAVER_DEFINE:-}" ]] && RUN_ARGS+=(${NAVER_DEFINE})

exec flutter run -d "${DEVICE}" "${RUN_ARGS[@]}"
