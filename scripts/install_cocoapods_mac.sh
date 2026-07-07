#!/usr/bin/env bash
# macOS — CocoaPods 설치
set -euo pipefail

# shellcheck source=scripts/ensure_ssl_certs.sh
source "$(dirname "${BASH_SOURCE[0]}")/ensure_ssl_certs.sh"

iljari_cocoapods_gem_bin() {
  ruby -e 'puts Gem.user_dir' 2>/dev/null
}

iljari_cocoapods_export_path() {
  local gem_bin
  gem_bin="$(iljari_cocoapods_gem_bin)/bin"
  if [[ -d "${gem_bin}" ]]; then
    export PATH="${gem_bin}:${PATH}"
  fi
}

iljari_system_ruby_major() {
  ruby -e 'puts RUBY_VERSION.split(".")[0].to_i' 2>/dev/null || echo 0
}

iljari_install_cocoapods_mac() {
  if command -v pod >/dev/null 2>&1; then
    return 0
  fi

  iljari_cocoapods_export_path
  command -v pod >/dev/null 2>&1 && return 0

  if ! xcode-select -p >/dev/null 2>&1; then
    echo "[CocoaPods] Xcode Command Line Tools 필요 — 설치 창이 뜨면 설치 후 다시 실행하세요." >&2
    xcode-select --install 2>/dev/null || true
    return 1
  fi

  # Homebrew가 있으면 가장 간단
  if command -v brew >/dev/null 2>&1; then
    echo "[CocoaPods] Homebrew로 설치…" >&2
    brew install cocoapods
    return 0
  fi

  local ruby_major
  ruby_major="$(iljari_system_ruby_major)"

  # macOS 기본 Ruby 2.6 → CocoaPods 최신 gem과 호환 불가 → Ruby 3.3 직접 설치
  if [[ "${ruby_major}" -lt 3 ]]; then
    echo "[CocoaPods] macOS Ruby 2.6 — Ruby 3.3을 ~/.iljari 에 설치합니다." >&2
    # shellcheck source=scripts/install_ruby33_mac.sh
    source "$(dirname "${BASH_SOURCE[0]}")/install_ruby33_mac.sh"
    iljari_install_ruby33_mac || return 1
    iljari_ruby33_export_path
  elif [[ -x "${HOME}/.iljari/ruby-3.3/bin/ruby" ]]; then
    # 이전 설치가 OpenSSL 없이 끝난 경우 재빌드
    # shellcheck source=scripts/install_ruby33_mac.sh
    source "$(dirname "${BASH_SOURCE[0]}")/install_ruby33_mac.sh"
    if ! iljari_ruby33_has_openssl || ! iljari_ruby33_has_psych; then
      echo "[CocoaPods] Ruby OpenSSL/psych 미연동 — 재설치합니다." >&2
      iljari_install_ruby33_mac || return 1
    fi
    iljari_ruby33_export_path
  fi

  if ! ruby -ropenssl -e 'exit 0' 2>/dev/null || ! ruby -rpsych -e 'exit 0' 2>/dev/null; then
    echo "[CocoaPods] Ruby OpenSSL/psych 없음 — gem install 불가" >&2
    return 1
  fi

  iljari_ensure_ssl_certs || {
    echo "[CocoaPods] CA 인증서(SSL_CERT_FILE) 준비 실패 — pod install 불가" >&2
    return 1
  }

  echo "" >&2
  echo "[CocoaPods] gem install cocoapods (5~10분)…" >&2
  echo "" >&2

  gem install cocoapods --no-document --verbose

  iljari_cocoapods_export_path
  if ! command -v pod >/dev/null 2>&1; then
    echo "pod 명령을 찾지 못했습니다. PATH: $(command -v ruby)" >&2
    return 1
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iljari_install_cocoapods_mac
  pod --version
fi
