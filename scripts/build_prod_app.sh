#!/usr/bin/env bash
# 실서비스 앱 빌드 (+ 스토어 업로드 — credentials 있을 때)
# Usage:
#   ./scripts/build_prod_app.sh              # AAB + APK + iOS(no codesign)
#   ./scripts/build_prod_app.sh --upload     # 빌드 후 fastlane 업로드 시도 (실패 시 exit 1)
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"

# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh
# shellcheck source=scripts/naver_flutter_defines.sh
source scripts/naver_flutter_defines.sh

STRICT_UPLOAD=0
for arg in "$@"; do
  case "${arg}" in
    --upload) STRICT_UPLOAD=1 ;;
    -h|--help)
      echo "Usage: $0 [--upload]"
      exit 0
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      exit 1
      ;;
  esac
done

naver_sync_flutter_defines || true

API_URL="$(iljari_resolve_compliance_api_url)"
ADMIN_KEY="$(iljari_resolve_admin_api_key)"

VERSION_LINE="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
VERSION_NAME="${VERSION_LINE%%+*}"
BUILD_NUMBER="${VERSION_LINE#*+}"

COMMON_DEFINES=(
  "--dart-define=QC_MODE=false"
  "--dart-define=COMPLIANCE_API_URL=${API_URL}"
  "--dart-define=ADMIN_API_KEY=${ADMIN_KEY}"
)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [App] 실서비스 빌드"
echo "  version : ${VERSION_NAME} (${BUILD_NUMBER})"
echo "  package : kr.co.iljari.app"
echo "  API     : ${API_URL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

flutter pub get

echo "[App 1/3] Android App Bundle (Play Store)..."
# shellcheck disable=SC2086
flutter build appbundle --release ${COMMON_DEFINES[@]} ${NAVER_DEFINE}

echo "[App 2/3] Android APK (실기기 sideload)..."
# shellcheck disable=SC2086
flutter build apk --release ${COMMON_DEFINES[@]} ${NAVER_DEFINE}
mkdir -p releases
APK_SRC="build/app/outputs/flutter-apk/app-release.apk"
APK_OUT="releases/iljari-${VERSION_NAME}-android.apk"
cp -f "${APK_SRC}" "${APK_OUT}"
cp -f "${APK_SRC}" "releases/iljari-android-latest.apk"

if [[ "$(uname)" == "Darwin" ]]; then
  echo "[App 3/3] iOS release (no codesign — Archive/TestFlight는 Xcode·fastlane)..."
  # shellcheck disable=SC2086
  flutter build ios --release --no-codesign ${COMMON_DEFINES[@]} ${NAVER_DEFINE}
else
  echo "[App 3/3] iOS — macOS에서만 빌드 (건너뜀)"
fi

echo ""
echo "✅ 앱 빌드 산출물:"
echo "  AAB : android/app/build/outputs/bundle/release/app-release.aab"
echo "  APK : ${ILJARI_ROOT}/${APK_OUT}"
echo "  APK : ${ILJARI_ROOT}/releases/iljari-android-latest.apk"
if [[ "$(uname)" == "Darwin" ]]; then
  echo "  iOS : ios/ (Xcode Archive → TestFlight)"
fi

UPLOAD_FAILED=0
CAN_PLAY=0
CAN_IOS=0

if [[ -f "${ILJARI_ROOT}/fastlane/play-store-key.json" ]]; then
  CAN_PLAY=1
fi
if [[ "$(uname)" == "Darwin" ]] && [[ -n "${FASTLANE_USER:-}" ]]; then
  CAN_IOS=1
fi

if [[ "${CAN_PLAY}" == 0 && "${CAN_IOS}" == 0 ]]; then
  echo ""
  echo "ℹ️  스토어 자동 업로드 — credentials 미설정 (빌드만 완료)"
  echo "   Play : fastlane/play-store-key.json + bundle exec fastlane android beta"
  echo "   iOS  : FASTLANE_USER + bundle exec fastlane ios beta"
  exit 0
fi

if ! command -v bundle >/dev/null 2>&1; then
  echo ""
  echo "⚠️  bundle(gem) 없음 — 스토어 업로드 건너뜀"
  [[ "${STRICT_UPLOAD}" == 1 ]] && exit 1
  exit 0
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  [App] 스토어 업로드"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${CAN_PLAY}" == 1 ]]; then
  echo "[Store] Play Console internal track..."
  if (cd "${ILJARI_ROOT}" && bundle exec fastlane android beta); then
    echo "✅ Play Console internal track"
  else
    echo "❌ Play upload failed"
    UPLOAD_FAILED=1
  fi
fi

if [[ "${CAN_IOS}" == 1 ]]; then
  echo "[Store] TestFlight..."
  if (cd "${ILJARI_ROOT}" && bundle exec fastlane ios beta); then
    echo "✅ TestFlight upload"
  else
    echo "❌ TestFlight upload failed (서명·FASTLANE 설정 확인)"
    UPLOAD_FAILED=1
  fi
fi

if [[ "${UPLOAD_FAILED}" == 1 ]]; then
  [[ "${STRICT_UPLOAD}" == 1 ]] && exit 1
  echo ""
  echo "⚠️  일부 스토어 업로드 실패 — AAB/APK는 releases/ 에 있습니다"
  exit 0
fi

echo ""
echo "✅ 앱 빌드·스토어 업로드 완료"
exit 0
