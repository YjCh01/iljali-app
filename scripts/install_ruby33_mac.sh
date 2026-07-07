#!/usr/bin/env bash
# macOS — Ruby 3.3 소스 빌드 → ~/.iljari/ruby-3.3 (Homebrew 불필요)
set -euo pipefail

RUBY_VERSION="3.3.7"
RUBY_PREFIX="${HOME}/.iljari/ruby-3.3"
RUBY_TAR="ruby-${RUBY_VERSION}.tar.gz"
RUBY_URL="https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/${RUBY_TAR}"

iljari_ruby33_binary_ready() {
  [[ -x "${RUBY_PREFIX}/bin/ruby" ]]
}

iljari_ruby33_has_openssl() {
  iljari_ruby33_binary_ready &&
    "${RUBY_PREFIX}/bin/ruby" -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION' >/dev/null 2>&1
}

iljari_ruby33_has_psych() {
  iljari_ruby33_binary_ready &&
    "${RUBY_PREFIX}/bin/ruby" -rpsych -e 'exit 0' >/dev/null 2>&1
}

iljari_ruby33_ready() {
  iljari_ruby33_has_openssl && iljari_ruby33_has_psych
}

iljari_ruby33_export_path() {
  if iljari_ruby33_binary_ready; then
    export PATH="${RUBY_PREFIX}/bin:${PATH}"
  fi
}

iljari_install_ruby33_mac() {
  if iljari_ruby33_ready; then
    iljari_ruby33_export_path
    return 0
  fi

  # OpenSSL/psych 없이 설치된 Ruby가 있으면 재빌드
  if iljari_ruby33_binary_ready && ! iljari_ruby33_ready; then
    echo "[Ruby] OpenSSL/psych 미지원 Ruby 감지 — 재설치합니다." >&2
    rm -rf "${RUBY_PREFIX}"
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    echo "[Ruby] Xcode Command Line Tools 필요" >&2
    xcode-select --install 2>/dev/null || true
    return 1
  fi

  for cmd in curl tar make cc; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "[Ruby] ${cmd} 명령이 필요합니다." >&2
      return 1
    fi
  done

  # shellcheck source=scripts/install_openssl_mac.sh
  source "$(dirname "${BASH_SOURCE[0]}")/install_openssl_mac.sh"
  iljari_install_openssl_mac || return 1
  iljari_openssl_export_env

  # shellcheck source=scripts/install_libyaml_mac.sh
  source "$(dirname "${BASH_SOURCE[0]}")/install_libyaml_mac.sh"
  iljari_install_libyaml_mac || return 1
  iljari_libyaml_export_env

  local openssl_dir libyaml_dir tmp build_jobs
  openssl_dir="${OPENSSL_PREFIX}"
  libyaml_dir="${LIBYAML_PREFIX}"
  if ! [[ -f "${openssl_dir}/include/openssl/ssl.h" ]]; then
    echo "[Ruby] OpenSSL 헤더를 찾지 못했습니다: ${openssl_dir}" >&2
    return 1
  fi
  if ! [[ -f "${libyaml_dir}/include/yaml.h" ]]; then
    echo "[Ruby] libyaml 헤더를 찾지 못했습니다: ${libyaml_dir}" >&2
    return 1
  fi

  tmp="$(mktemp -d)"
  build_jobs="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

  echo "[Ruby] ${RUBY_VERSION} 다운로드 (최초 1회, 수 분~20분)…" >&2
  echo "       CocoaPods용 — macOS 기본 Ruby 2.6 대체" >&2
  echo "       OpenSSL: ${openssl_dir}" >&2
  echo "       libyaml: ${libyaml_dir}" >&2
  echo "" >&2

  curl -fsSL --progress-bar "${RUBY_URL}" -o "${tmp}/${RUBY_TAR}"
  tar -xzf "${tmp}/${RUBY_TAR}" -C "${tmp}"

  echo "[Ruby] 컴파일 중 (CPU ${build_jobs}코어, 10~20분)…" >&2
  echo "       로그가 멈춘 것처럼 보여도 정상입니다." >&2
  echo "" >&2

  (
    cd "${tmp}/ruby-${RUBY_VERSION}"
    ./configure \
      --prefix="${RUBY_PREFIX}" \
      --disable-install-doc \
      --with-out-ext=tk \
      --with-openssl-dir="${openssl_dir}" \
      --with-libyaml-dir="${libyaml_dir}"
    make -j"${build_jobs}"
    make install
  )

  rm -rf "${tmp}"

  if ! iljari_ruby33_ready; then
    echo "[Ruby] 설치 후 OpenSSL/psych 연동 실패 — gem install 이 동작하지 않을 수 있습니다." >&2
    if iljari_ruby33_binary_ready; then
      "${RUBY_PREFIX}/bin/ruby" -ropenssl -e 'puts 1' 2>&1 || true
    else
      echo "[Ruby] ruby 실행 파일 없음: ${RUBY_PREFIX}/bin/ruby" >&2
    fi
    return 1
  fi

  iljari_ruby33_export_path
  echo "[Ruby] 설치 완료: $("${RUBY_PREFIX}/bin/ruby" -v)" >&2
  echo "[Ruby] OpenSSL: $("${RUBY_PREFIX}/bin/ruby" -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION')" >&2
  echo "[Ruby] psych: OK" >&2
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iljari_install_ruby33_mac
  "${RUBY_PREFIX}/bin/ruby" -v
  "${RUBY_PREFIX}/bin/ruby" -ropenssl -e 'puts OpenSSL::OPENSSL_VERSION'
fi
