#!/usr/bin/env bash
# 자체 빌드 OpenSSL(Ruby/CocoaPods)용 CA 인증서 번들
ILJARI_SSL_DIR="${HOME}/.iljari/ssl"
ILJARI_CACERT="${ILJARI_SSL_DIR}/cacert.pem"
ILJARI_CACERT_URL="https://curl.se/ca/cacert.pem"

iljari_ensure_ssl_certs() {
  local quiet=0
  if [[ "${1:-}" == "--quiet" ]]; then
    quiet=1
  fi

  if [[ -f "${ILJARI_CACERT}" ]]; then
    export SSL_CERT_FILE="${ILJARI_CACERT}"
    unset SSL_CERT_DIR 2>/dev/null || true
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    [[ "${quiet}" -eq 0 ]] && echo "[SSL] curl 필요 — CA 인증서 다운로드 불가" >&2
    return 1
  fi

  mkdir -p "${ILJARI_SSL_DIR}"
  if [[ "${quiet}" -eq 0 ]]; then
    echo "[SSL] CA 인증서 다운로드 (CocoaPods HTTPS용)…" >&2
  fi

  if ! curl -fsSL "${ILJARI_CACERT_URL}" -o "${ILJARI_CACERT}.tmp"; then
    rm -f "${ILJARI_CACERT}.tmp"
    [[ "${quiet}" -eq 0 ]] && echo "[SSL] CA 인증서 다운로드 실패: ${ILJARI_CACERT_URL}" >&2
    return 1
  fi

  if ! grep -q "BEGIN CERTIFICATE" "${ILJARI_CACERT}.tmp" 2>/dev/null; then
    rm -f "${ILJARI_CACERT}.tmp"
    [[ "${quiet}" -eq 0 ]] && echo "[SSL] 다운로드 파일이 유효한 CA 번들이 아닙니다." >&2
    return 1
  fi

  mv "${ILJARI_CACERT}.tmp" "${ILJARI_CACERT}"
  export SSL_CERT_FILE="${ILJARI_CACERT}"
  unset SSL_CERT_DIR 2>/dev/null || true

  if [[ "${quiet}" -eq 0 ]]; then
    echo "[SSL] SSL_CERT_FILE=${SSL_CERT_FILE}" >&2
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  iljari_ensure_ssl_certs
  echo "SSL_CERT_FILE=${SSL_CERT_FILE}"
  wc -l < "${ILJARI_CACERT}"
fi
