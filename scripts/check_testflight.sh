#!/usr/bin/env bash
# TestFlight / App Store Connect 상태 점검 (터미널)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
export ILJARI_ROOT="${ROOT}"

# shellcheck source=scripts/iljari_ios_env.sh
source scripts/iljari_ios_env.sh

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TestFlight 점검"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

iljari_ios_load_env
export FASTLANE_USER FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD APPLE_TEAM_ID
if [[ -n "${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}" ]]; then
  export FASTLANE_PASSWORD="${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD}"
fi

echo ""
iljari_ios_preflight || true

IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}')"
echo ""
echo "[로컬]"
echo "  pubspec version : ${VERSION}"
if [[ -n "${IPA}" ]]; then
  echo "  IPA             : ${IPA} ($(ls -lh "${IPA}" | awk '{print $5}'))"
else
  echo "  IPA             : 없음"
fi
echo "  Bundle ID       : kr.co.iljari.app"
echo "  Team ID         : ${APPLE_TEAM_ID:-?}"

export PATH="${HOME}/.iljari/ruby-3.3/bin:${PATH}"
gem_bin="$("${HOME}/.iljari/ruby-3.3/bin/ruby" -e 'puts Gem.user_dir' 2>/dev/null)/bin"
[[ -d "${gem_bin}" ]] && export PATH="${gem_bin}:${PATH}"

# shellcheck source=scripts/ensure_ssl_certs.sh
source scripts/ensure_ssl_certs.sh
if ! iljari_ensure_ssl_certs --quiet; then
  echo ""
  echo "❌ SSL CA 인증서 없음 — App Store Connect HTTPS 실패"
  echo "   ./scripts/ensure_ssl_certs.sh"
  echo "   (CocoaPods·fastlane 공통 — ~/.iljari/ssl/cacert.pem)"
  exit 1
fi
export SSL_CERT_FILE="${SSL_CERT_FILE:-${HOME}/.iljari/ssl/cacert.pem}"

if [[ -z "${FASTLANE_USER:-}" || -z "${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}" ]]; then
  echo ""
  echo "❌ fastlane/.env — Apple ID·앱전용비밀번호 필요"
  exit 1
fi

echo ""
echo "[App Store Connect — 빌드 조회]"
if bundle exec fastlane ios check_builds 2>&1; then
  :
else
  echo ""
  echo "⚠️  ASC 조회 실패 — 아래 수동 확인:"
  echo "   1) appstoreconnect.apple.com → 일자리 → TestFlight → iOS 빌드"
  echo "   2) 「수출 규정」대기면 → 아니오(표준 암호화만)"
  echo "   3) 내부 테스팅 iljari 그룹 → 빌드 1.0.0 (2) 추가"
  echo "   4) 없으면: ./scripts/upload_testflight.sh --upload-only"
fi
echo ""
