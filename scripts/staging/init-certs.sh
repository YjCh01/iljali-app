#!/usr/bin/env bash
# Self-signed TLS for local staging (browser trust once).
set -euo pipefail

ILJARI_ROOT="${ILJARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CERT_DIR="${ILJARI_ROOT}/server/staging/certs"
APP_HOST="${STAGING_APP_HOST:-app.staging.iljari.local}"
API_HOST="${STAGING_API_HOST:-api.staging.iljari.local}"

mkdir -p "${CERT_DIR}"

if [[ -f "${CERT_DIR}/fullchain.pem" && -f "${CERT_DIR}/privkey.pem" ]]; then
  echo "[staging] TLS certs already exist at ${CERT_DIR}"
  exit 0
fi

echo "[staging] Generating self-signed cert (SAN: ${APP_HOST}, ${API_HOST}) ..."
openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
  -keyout "${CERT_DIR}/privkey.pem" \
  -out "${CERT_DIR}/fullchain.pem" \
  -subj "/CN=staging.iljari.local" \
  -addext "subjectAltName=DNS:${APP_HOST},DNS:${API_HOST}" 2>/dev/null \
  || openssl req -x509 -nodes -days 825 -newkey rsa:2048 \
    -keyout "${CERT_DIR}/privkey.pem" \
    -out "${CERT_DIR}/fullchain.pem" \
    -subj "/CN=staging.iljari.local"

echo "[staging] Certs written to ${CERT_DIR}"
