#!/usr/bin/env bash
# IPA 빌드 + TestFlight 업로드
# Usage:
#   ./scripts/upload_testflight.sh              # 빌드 + 업로드
#   ./scripts/upload_testflight.sh --upload-only  # 기존 IPA만 업로드
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
export ILJARI_ROOT="${ROOT}"

UPLOAD_ONLY=0
for arg in "$@"; do
  case "${arg}" in
    --upload-only) UPLOAD_ONLY=1 ;;
    -h|--help)
      echo "Usage: $0 [--upload-only]"
      exit 0
      ;;
  esac
done

# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh
# shellcheck source=scripts/naver_flutter_defines.sh
source scripts/naver_flutter_defines.sh
# shellcheck source=scripts/ensure_cocoapods.sh
source scripts/ensure_cocoapods.sh
# shellcheck source=scripts/iljari_ios_env.sh
source scripts/iljari_ios_env.sh

iljari_ios_load_env
export APPLE_TEAM_ID FASTLANE_USER FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
export ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH
# Apple ID 방식: fastlane이 계정 비밀번호 대신 앱 전용 비밀번호 사용
if [[ -n "${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}" ]]; then
  export FASTLANE_PASSWORD="${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD}"
fi

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  echo "❌ Team ID 없음"
  echo "   Xcode → Runner → Signing → Team 선택"
  echo "   또는 ./scripts/setup_testflight.sh"
  exit 1
fi

if ! iljari_ios_has_upload_credentials; then
  echo "❌ TestFlight 업로드 인증 없음"
  echo ""
  echo "   가장 쉬운 방법 (더블클릭):"
  echo "   → 도구_TestFlight비밀번호갱신.command"
  echo ""
  echo "   또는: ./scripts/refresh_testflight_password.sh"
  exit 1
fi

if [[ "$(iljari_ios_signing_identity_count)" == 0 ]]; then
  echo "❌ Mac 키체인에 iOS 서명 인증서 없음"
  echo "   Xcode → Accounts · Runner Signing & Capabilities"
  exit 1
fi

export PATH="${HOME}/.iljari/ruby-3.3/bin:${PATH}"
gem_bin="$("${HOME}/.iljari/ruby-3.3/bin/ruby" -e 'puts Gem.user_dir' 2>/dev/null)/bin"
[[ -d "${gem_bin}" ]] && export PATH="${gem_bin}:${PATH}"

# shellcheck source=scripts/ensure_ssl_certs.sh
source scripts/ensure_ssl_certs.sh
if ! iljari_ensure_ssl_certs --quiet; then
  echo "❌ SSL CA 인증서 없음 — ./scripts/ensure_ssl_certs.sh 실행 후 재시도"
  exit 1
fi
export SSL_CERT_FILE="${SSL_CERT_FILE:-${HOME}/.iljari/ssl/cacert.pem}"

iljari_ensure_cocoapods --quiet || {
  echo "❌ CocoaPods 없음 — 도구_CocoaPods설치.command"
  exit 1
}

if ! command -v bundle >/dev/null 2>&1; then
  echo "❌ bundle(gem) 없음 — cd ${ROOT} && bundle install"
  exit 1
fi

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
if [[ "${UPLOAD_ONLY}" == 1 ]]; then
  echo "  TestFlight — 업로드만 (기존 IPA)"
else
  echo "  TestFlight — IPA build + 업로드"
fi
echo "  ${VERSION_NAME} (${BUILD_NUMBER}) · team ${APPLE_TEAM_ID}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

flutter pub get
bundle install --quiet 2>/dev/null || bundle install

if [[ "${UPLOAD_ONLY}" == 1 ]]; then
  IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
  if [[ -z "${IPA}" ]]; then
    echo "❌ IPA 없음 — 전체 빌드: ./scripts/upload_testflight.sh"
    exit 1
  fi
  echo "  기존 IPA 사용: ${IPA}"
  echo "[1/1] TestFlight 업로드…"
  bundle exec fastlane ios beta
else
echo "[1/3] Xcode 서명 설정…"
export APPLE_TEAM_ID
bundle exec fastlane ios prepare_signing

echo "[2/3] flutter build ipa…"
# shellcheck disable=SC2086
flutter build ipa --release \
  --build-name="${VERSION_NAME}" \
  --build-number="${BUILD_NUMBER}" \
  --export-options-plist=ios/ExportOptionsAppStore.plist \
  ${COMMON_DEFINES[@]} ${NAVER_DEFINE}

IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
if [[ -z "${IPA}" ]]; then
  echo "❌ IPA 생성 실패"
  echo "   · Xcode → Runner → Signing (Team ${APPLE_TEAM_ID})"
  echo "   · ios/Runner.xcworkspace 열어 Archive 테스트"
  exit 1
fi
echo "  IPA: ${IPA}"

echo "[3/3] TestFlight 업로드…"
bundle exec fastlane ios beta
fi

echo ""
echo "✅ TestFlight 업로드 요청 완료"
echo "   App Store Connect → TestFlight → 처리·테스터 추가"
echo "   (처리 5~15분 소요될 수 있음)"
echo ""
