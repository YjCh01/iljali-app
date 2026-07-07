#!/usr/bin/env bash
# Homebrew 없이 Eclipse Temurin JDK 17 다운로드 → ~/.iljari/jdk-17
set -euo pipefail

ILJARI_JDK_ROOT="${HOME}/.iljari/jdk-17"
ILJARI_JDK_HOME="${ILJARI_JDK_ROOT}/Contents/Home"

iljari_openjdk17_home() {
  if [[ -x "${ILJARI_JDK_HOME}/bin/java" ]]; then
    printf '%s' "${ILJARI_JDK_HOME}"
    return 0
  fi
  return 1
}

iljari_install_openjdk17_mac() {
  # stdout = 경로만 (command substitution 오염 방지). 진행 메시지는 stderr.
  if home="$(iljari_openjdk17_home)"; then
    printf '%s' "${home}"
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    echo "curl이 필요합니다 (macOS 기본 포함)." >&2
    return 1
  fi

  local arch uname_arch
  uname_arch="$(uname -m)"
  case "${uname_arch}" in
    arm64 | aarch64) arch="aarch64" ;;
    x86_64) arch="x86_64" ;;
    *)
      echo "지원하지 않는 Mac CPU: ${uname_arch}" >&2
      return 1
      ;;
  esac

  local url tmp tar extracted
  url="https://api.adoptium.net/v3/binary/latest/17/ga/mac/${arch}/jdk/hotspot/normal/eclipse?project=jdk"
  tmp="$(mktemp -d)"
  tar="${tmp}/openjdk17.tar.gz"

  echo "[Java] JDK 17 다운로드 중 (약 180MB, 2~5분)…" >&2
  echo "       Temurin · ${arch}" >&2
  if ! curl -fsSL --progress-bar "${url}" -o "${tar}"; then
    rm -rf "${tmp}"
    echo "다운로드 실패 — 인터넷 연결을 확인하세요." >&2
    return 1
  fi

  echo "[Java] 압축 해제…" >&2
  mkdir -p "${tmp}/extract"
  tar -xzf "${tar}" -C "${tmp}/extract"
  extracted="$(find "${tmp}/extract" -maxdepth 1 -type d -name 'jdk-*' | head -1)"
  if [[ -z "${extracted}" || ! -d "${extracted}/Contents/Home" ]]; then
    rm -rf "${tmp}"
    echo "압축 해제 형식 오류" >&2
    return 1
  fi

  rm -rf "${ILJARI_JDK_ROOT}"
  mkdir -p "${HOME}/.iljari"
  mv "${extracted}" "${ILJARI_JDK_ROOT}"
  rm -rf "${tmp}"

  if [[ ! -x "${ILJARI_JDK_HOME}/bin/java" ]]; then
    echo "설치 후 java 실행 파일 없음: ${ILJARI_JDK_HOME}" >&2
    return 1
  fi

  echo "[Java] 설치 완료: ${ILJARI_JDK_HOME}" >&2
  printf '%s' "${ILJARI_JDK_HOME}"
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iljari_install_openjdk17_mac
  echo ""
fi
