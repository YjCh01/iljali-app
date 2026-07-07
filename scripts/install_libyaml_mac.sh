#!/usr/bin/env bash
# macOS — libyaml 소스 빌드 → ~/.iljari/libyaml (Ruby psych 확장용)
set -euo pipefail

LIBYAML_VERSION="0.2.5"
LIBYAML_PREFIX="${HOME}/.iljari/libyaml"
LIBYAML_TAR="yaml-${LIBYAML_VERSION}.tar.gz"
LIBYAML_URL="https://pyyaml.org/download/libyaml/${LIBYAML_TAR}"

iljari_libyaml_ready() {
  [[ -f "${LIBYAML_PREFIX}/include/yaml.h" ]] &&
    { [[ -f "${LIBYAML_PREFIX}/lib/libyaml.a" ]] || [[ -f "${LIBYAML_PREFIX}/lib/libyaml.dylib" ]]; }
}

iljari_libyaml_export_env() {
  if iljari_libyaml_ready; then
    export LDFLAGS="-L${LIBYAML_PREFIX}/lib ${LDFLAGS:-}"
    export CPPFLAGS="-I${LIBYAML_PREFIX}/include ${CPPFLAGS:-}"
    export PKG_CONFIG_PATH="${LIBYAML_PREFIX}/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
  fi
}

iljari_install_libyaml_mac() {
  if iljari_libyaml_ready; then
    iljari_libyaml_export_env
    return 0
  fi

  if command -v brew >/dev/null 2>&1; then
    echo "[libyaml] Homebrew로 libyaml 설치…" >&2
    brew install libyaml 2>/dev/null || brew install libyaml
    local brew_prefix
    brew_prefix="$(brew --prefix libyaml)"
    if [[ -f "${brew_prefix}/include/yaml.h" ]]; then
      export LIBYAML_PREFIX="${brew_prefix}"
      iljari_libyaml_export_env
      echo "[libyaml] Homebrew: ${LIBYAML_PREFIX}" >&2
      return 0
    fi
    LIBYAML_PREFIX="${HOME}/.iljari/libyaml"
  fi

  if ! xcode-select -p >/dev/null 2>&1; then
    echo "[libyaml] Xcode Command Line Tools 필요" >&2
    xcode-select --install 2>/dev/null || true
    return 1
  fi

  for cmd in curl tar make cc; do
    if ! command -v "${cmd}" >/dev/null 2>&1; then
      echo "[libyaml] ${cmd} 명령이 필요합니다." >&2
      return 1
    fi
  done

  local tmp build_jobs
  tmp="$(mktemp -d)"
  build_jobs="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

  echo "[libyaml] ${LIBYAML_VERSION} 다운로드…" >&2
  curl -fsSL --progress-bar "${LIBYAML_URL}" -o "${tmp}/${LIBYAML_TAR}"
  tar -xzf "${tmp}/${LIBYAML_TAR}" -C "${tmp}"

  echo "[libyaml] 컴파일 중 (1~2분)…" >&2
  mkdir -p "${LIBYAML_PREFIX}"
  (
    cd "${tmp}/yaml-${LIBYAML_VERSION}"
    ./configure --prefix="${LIBYAML_PREFIX}" --disable-shared
    make -j"${build_jobs}"
    make install
  )
  rm -rf "${tmp}"

  if ! iljari_libyaml_ready; then
    echo "[libyaml] 설치 실패: ${LIBYAML_PREFIX}" >&2
    return 1
  fi

  iljari_libyaml_export_env
  echo "[libyaml] 설치 완료: ${LIBYAML_PREFIX}" >&2
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iljari_install_libyaml_mac
  ls "${LIBYAML_PREFIX}/include/yaml.h"
fi
