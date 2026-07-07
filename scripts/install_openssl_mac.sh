#!/usr/bin/env bash
# macOS — OpenSSL 3.x 소스 빌드 → ~/.iljari/openssl (Homebrew 불필요)
set -euo pipefail

OPENSSL_VERSION="3.3.2"
OPENSSL_PREFIX="${HOME}/.iljari/openssl"
OPENSSL_TAR="openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_TAR}"

iljari_openssl_ready() {
  [[ -f "${OPENSSL_PREFIX}/lib/libssl.a" || -f "${OPENSSL_PREFIX}/lib/libssl.dylib" ]] &&
    [[ -f "${OPENSSL_PREFIX}/include/openssl/ssl.h" ]]
}

iljari_openssl_export_env() {
  if iljari_openssl_ready; then
    export PATH="${OPENSSL_PREFIX}/bin:${PATH}"
    export LDFLAGS="-L${OPENSSL_PREFIX}/lib ${LDFLAGS:-}"
    export CPPFLAGS="-I${OPENSSL_PREFIX}/include ${CPPFLAGS:-}"
    export PKG_CONFIG_PATH="${OPENSSL_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  fi
}

iljari_install_openssl_mac() {
  if iljari_openssl_ready; then
    iljari_openssl_export_env
    return 0
  fi

  # Homebrew가 있으면 bottle 설치가 훨씬 빠름
  if command -v brew >/dev/null 2>&1; then
    echo "[OpenSSL] Homebrew로 openssl@3 설치…" >&2
    brew install openssl@3 2>/dev/null || brew install openssl@3
    local brew_prefix
    brew_prefix="$(brew --prefix openssl@3)"
    if [[ -f "${brew_prefix}/include/openssl/ssl.h" ]]; then
      export OPENSSL_PREFIX="${brew_prefix}"
      iljari_openssl_export_env
      echo "[OpenSSL] Homebrew: ${OPENSSL_PREFIX}" >&2
      return 0
    fi
    OPENSSL_PREFIX="${HOME}/.iljari/openssl"
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    echo "[OpenSSL] Xcode Command Line Tools 필요" >&2
    xcode-select --install 2>/dev/null || true
    return 1
  fi

  for cmd in curl tar make cc; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "[OpenSSL] ${cmd} 명령이 필요합니다." >&2
      return 1
    fi
  done

  local tmp build_jobs configure_target arch
  tmp="$(mktemp -d)"
  build_jobs="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"
  arch="$(uname -m)"
  case "${arch}" in
    arm64) configure_target="darwin64-arm64-cc" ;;
    x86_64) configure_target="darwin64-x86_64-cc" ;;
    *)
      echo "[OpenSSL] 지원하지 않는 CPU: ${arch}" >&2
      return 1
      ;;
  esac

  echo "[OpenSSL] ${OPENSSL_VERSION} 다운로드 (최초 1회, 수 분)…" >&2
  echo "       Ruby gem(HTTPS)용 — ~/.iljari/openssl" >&2
  echo "" >&2

  curl -fsSL --progress-bar "${OPENSSL_URL}" -o "${tmp}/${OPENSSL_TAR}"
  tar -xzf "${tmp}/${OPENSSL_TAR}" -C "${tmp}"

  echo "[OpenSSL] 컴파일 중 (CPU ${build_jobs}코어, 3~8분)…" >&2
  echo "" >&2

  mkdir -p "${OPENSSL_PREFIX}"
  (
    cd "${tmp}/openssl-${OPENSSL_VERSION}"
    ./Configure "${configure_target}" \
      --prefix="${OPENSSL_PREFIX}" \
      --openssldir="${OPENSSL_PREFIX}" \
      no-shared
    make -j"${build_jobs}"
    make install_sw
  )

  rm -rf "${tmp}"

  if ! iljari_openssl_ready; then
    echo "[OpenSSL] 설치 후 libssl 없음: ${OPENSSL_PREFIX}" >&2
    return 1
  fi

  iljari_openssl_export_env
  echo "[OpenSSL] 설치 완료: ${OPENSSL_PREFIX}" >&2
  "${OPENSSL_PREFIX}/bin/openssl" version >&2 || true
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iljari_install_openssl_mac
  "${OPENSSL_PREFIX}/bin/openssl" version 2>/dev/null || openssl version
fi
