#!/usr/bin/env bash
# Android(Gradle) · iOS(CocoaPods) 빌드용 도구 PATH

_iljari_load_ssl_certs() {
  if [[ -n "${ILJARI_ENSURE_SSL_LOADED:-}" ]]; then
    return 0
  fi
  local scripts_dir
  scripts_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=scripts/ensure_ssl_certs.sh
  source "${scripts_dir}/ensure_ssl_certs.sh"
  ILJARI_ENSURE_SSL_LOADED=1
}

iljari_ensure_cocoapods() {
  local quiet=0
  if [[ "${1:-}" == "--quiet" ]]; then
    quiet=1
  fi

  _iljari_load_ssl_certs
  # 자체 빌드 OpenSSL — CA 번들 없으면 pod install SSL 실패
  iljari_ensure_ssl_certs --quiet || true

  # iljari Ruby 3.3 (CocoaPods용)
  if [[ -x "${HOME}/.iljari/ruby-3.3/bin/pod" ]]; then
    export PATH="${HOME}/.iljari/ruby-3.3/bin:${PATH}"
    local gem_bin
    gem_bin="$("${HOME}/.iljari/ruby-3.3/bin/ruby" -e 'puts Gem.user_dir' 2>/dev/null)/bin"
    [[ -d "${gem_bin}" ]] && export PATH="${gem_bin}:${PATH}"
    return 0
  fi
  if [[ -x "${HOME}/.iljari/ruby-3.3/bin/ruby" ]]; then
    export PATH="${HOME}/.iljari/ruby-3.3/bin:${PATH}"
    local gem_bin
    gem_bin="$("${HOME}/.iljari/ruby-3.3/bin/ruby" -e 'puts Gem.user_dir' 2>/dev/null)/bin"
    [[ -d "${gem_bin}" ]] && export PATH="${gem_bin}:${PATH}"
    command -v pod >/dev/null 2>&1 && return 0
  fi

  if command -v pod >/dev/null 2>&1; then
    return 0
  fi

  local gem_bin
  gem_bin="$(ruby -e 'puts Gem.user_dir' 2>/dev/null)/bin"
  if [[ -d "${gem_bin}" ]]; then
    export PATH="${gem_bin}:${PATH}"
    command -v pod >/dev/null 2>&1 && return 0
  fi

  if [[ "${quiet}" -eq 0 ]]; then
    echo ""
    echo "❌ iOS 빌드에 CocoaPods(pod)가 필요합니다."
    echo ""
    echo "  → 「도구_CocoaPods설치.command」 더블클릭"
    echo ""
    echo "  ※ Android AAB/APK는 이미 빌드됐을 수 있습니다."
    echo ""
  fi
  return 1
}
