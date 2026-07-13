#!/usr/bin/env bash
# Apple Transporter로 IPA 직접 업로드 (fastlane 대안)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

# shellcheck source=scripts/iljari_ios_env.sh
source scripts/iljari_ios_env.sh
# shellcheck source=scripts/ensure_ssl_certs.sh
source scripts/ensure_ssl_certs.sh

iljari_ios_load_env
iljari_ensure_ssl_certs --quiet || true
export SSL_CERT_FILE="${SSL_CERT_FILE:-${HOME}/.iljari/ssl/cacert.pem}"
export FASTLANE_PASSWORD="${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}"

IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
if [[ -z "${IPA}" ]]; then
  echo "❌ IPA 없음 — 먼저 ./scripts/upload_testflight.sh (빌드 포함) 실행"
  exit 1
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Transporter CLI 업로드"
echo "  ${IPA}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if [[ -z "${FASTLANE_USER:-}" || -z "${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}" ]]; then
  echo "❌ fastlane/.env — Apple ID + 앱전용비밀번호 필요"
  exit 1
fi

# Xcode 13+ iTMSTransporter
XCODE_APP="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" 2>/dev/null | head -1)"
if [[ -z "${XCODE_APP}" ]]; then
  XCODE_APP="/Applications/Xcode.app"
fi
TRANSPORTER="${XCODE_APP}/Contents/SharedFrameworks/ContentDelivery.framework/Resources/altool"
if [[ ! -x "${TRANSPORTER}" ]]; then
  TRANSPORTER="${XCODE_APP}/Contents/Applications/Application Loader.app/Contents/itms/bin/iTMSTransporter"
fi

if xcrun altool --help >/dev/null 2>&1; then
  echo "xcrun altool --upload-app …"
  xcrun altool --upload-app \
    --type ios \
    --file "${IPA}" \
    --username "${FASTLANE_USER}" \
    --password "@env:FASTLANE_PASSWORD"
else
  echo "❌ altool/Transporter CLI 없음"
  echo ""
  echo "Mac App Store → 「Transporter」 앱 설치 후"
  echo "  ${ROOT}/${IPA} 파일을 드래그 앤 드롭"
  echo ""
  open -a "Transporter" "${IPA}" 2>/dev/null || open "https://apps.apple.com/app/transporter/id1450874784"
  exit 1
fi

echo ""
echo "✅ Transporter 업로드 요청 완료 — 10~30분 후 App Store Connect TestFlight 확인"
echo ""
