#!/usr/bin/env bash
# Release builds — App Store / Play Store / staging web
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"

# shellcheck source=scripts/naver_flutter_defines.sh
source scripts/naver_flutter_defines.sh
naver_sync_flutter_defines || true

API_URL="${COMPLIANCE_API_URL:-https://api-staging.iljari.local}"
SENTRY_DSN="${SENTRY_DSN:-}"
TOSS_KEY="${TOSS_CLIENT_KEY:-}"
ADMIN_KEY="${ADMIN_API_KEY:-}"

COMMON_DEFINES=(
  "--dart-define=COMPLIANCE_API_URL=${API_URL}"
  "--dart-define=QC_MODE=false"
  "--dart-define=ADMIN_API_KEY=${ADMIN_KEY}"
)
if [[ -n "${SENTRY_DSN}" ]]; then
  COMMON_DEFINES+=("--dart-define=SENTRY_DSN=${SENTRY_DSN}")
fi
if [[ -n "${TOSS_KEY}" ]]; then
  COMMON_DEFINES+=("--dart-define=TOSS_CLIENT_KEY=${TOSS_KEY}")
fi

flutter pub get

echo "[release] Android App Bundle (kr.co.iljari.app) ..."
# shellcheck disable=SC2086
flutter build appbundle --release ${COMMON_DEFINES[@]} ${NAVER_DEFINE}

echo "[release] iOS (no codesign — CI에서 서명) ..."
# shellcheck disable=SC2086
flutter build ios --release --no-codesign ${COMMON_DEFINES[@]} ${NAVER_DEFINE}

echo "[release] Web (staging/production static) ..."
# shellcheck disable=SC2086
flutter build web --release ${COMMON_DEFINES[@]} ${WEB_DEFINE} ${NAVER_DEFINE}

echo
echo "Artifacts:"
echo "  android/app/build/outputs/bundle/release/app-release.aab"
echo "  build/web/"
echo "  ios/ — Xcode Archive 후 App Store Connect 업로드"
