#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

ZSHRC_MARKER="# iljari-ios-build-path"

pause_close() {
  read -r -p "Enter 키로 창 닫기…" _ || true
}

iljari_write_zshrc_paths() {
  local zshrc="${HOME}/.zshrc"
  local ruby_bin="${HOME}/.iljari/ruby-3.3/bin"
  local cacert="${HOME}/.iljari/ssl/cacert.pem"

  if [[ -f "${zshrc}" ]] && grep -q "${ZSHRC_MARKER}" "${zshrc}" 2>/dev/null; then
    sed -i '' "/${ZSHRC_MARKER}/,+2d" "${zshrc}" 2>/dev/null || true
  fi

  {
    echo ""
    echo "${ZSHRC_MARKER}"
    echo "export PATH=\"${ruby_bin}:\${PATH}\""
    echo "export SSL_CERT_FILE=\"${cacert}\""
  } >> "${zshrc}"
}

echo ""
echo "========================================"
echo "  iOS 빌드용 CocoaPods 설치"
echo "========================================"
echo ""
echo "App Store / TestFlight iOS 빌드에 필요합니다."
echo "Android만 쓰면 건너뛰어도 됩니다."
echo ""
echo "macOS Ruby 2.6은 최신 CocoaPods와 맞지 않아"
echo "OpenSSL + Ruby 3.3을 ~/.iljari 에 설치한 뒤 CocoaPods를 깝니다."
echo "이전에 실패했다면 OpenSSL 연동으로 Ruby를 자동 재설치합니다."
echo "최초 1회 20~40분 걸릴 수 있습니다."
echo ""

# shellcheck source=scripts/ensure_cocoapods.sh
source scripts/ensure_cocoapods.sh
  if iljari_ensure_cocoapods --quiet; then
    # shellcheck source=scripts/ensure_ssl_certs.sh
    source scripts/ensure_ssl_certs.sh
    iljari_ensure_ssl_certs || true
    echo "✅ CocoaPods가 이미 준비되어 있습니다."
  echo ""
  pod --version
  echo ""
  pause_close
  exit 0
fi

# shellcheck source=scripts/install_cocoapods_mac.sh
source scripts/install_cocoapods_mac.sh
if ! iljari_install_cocoapods_mac; then
  echo ""
  echo "❌ CocoaPods 설치에 실패했습니다."
  echo ""
  echo "  • xcode-select --install 실행 후 재시도"
  echo "  • Xcode App Store 설치 (권장)"
  echo ""
  pause_close
  exit 1
fi

if [[ -x "${HOME}/.iljari/ruby-3.3/bin/ruby" ]]; then
  # shellcheck source=scripts/ensure_ssl_certs.sh
  source scripts/ensure_ssl_certs.sh
  iljari_ensure_ssl_certs || true
  iljari_write_zshrc_paths
  echo "~/.zshrc 에 Ruby/CocoaPods PATH + SSL_CERT_FILE 저장했습니다."
fi

echo ""
pod --version
echo ""
echo "========================================"
echo "  ✅ CocoaPods 설치 완료"
echo "========================================"
echo ""
echo "  다음: 도구_실서비스한방배포(app포함).command"
echo ""

pause_close
