#!/usr/bin/env bash
# Android APK (release, debug signing) — 실기기 sideload·QC용
# Play 스토어 업로드는 ./scripts/build_release.sh → app-release.aab
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"

# shellcheck source=scripts/naver_flutter_defines.sh
source scripts/naver_flutter_defines.sh
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh
naver_sync_flutter_defines || true

API_URL="${COMPLIANCE_API_URL:-$(iljari_resolve_compliance_api_url)}"
ADMIN_KEY="$(iljari_resolve_admin_api_key)"
QC_MODE="${QC_MODE:-false}"
BUILD_KIND="${1:-release}"

VERSION_LINE="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE#*+}"

COMMON_DEFINES=(
  "--dart-define=QC_MODE=${QC_MODE}"
  "--dart-define=COMPLIANCE_API_URL=${API_URL}"
  "--dart-define=ADMIN_API_KEY=${ADMIN_KEY}"
)

echo
echo "========================================"
echo "  iljari Android APK (${BUILD_KIND})"
echo "  version: ${VERSION_NAME} (${BUILD_NUMBER})"
echo "  package: kr.co.iljari.app"
echo "  API: ${API_URL}"
echo "========================================"
echo

flutter pub get

if [[ "${BUILD_KIND}" == "debug" ]]; then
  # shellcheck disable=SC2086
  flutter build apk --debug ${COMMON_DEFINES[@]} ${NAVER_DEFINE}
  SRC_APK="build/app/outputs/flutter-apk/app-debug.apk"
  OUT_NAME="iljari-${VERSION_NAME}-android-debug.apk"
else
  # shellcheck disable=SC2086
  flutter build apk --release ${COMMON_DEFINES[@]} ${NAVER_DEFINE}
  SRC_APK="build/app/outputs/flutter-apk/app-release.apk"
  OUT_NAME="iljari-${VERSION_NAME}-android.apk"
fi

mkdir -p releases
cp -f "${SRC_APK}" "releases/${OUT_NAME}"
cp -f "${SRC_APK}" "releases/iljari-android-latest.apk"

echo
echo "완료:"
echo "  ${ILJARI_ROOT}/releases/${OUT_NAME}"
echo "  ${ILJARI_ROOT}/releases/iljari-android-latest.apk"
echo
echo "실기기 sideload — API는 NCP 기본 (로컬: ILJARI_API_MODE=local ./scripts/build_apk.sh)"
