#!/usr/bin/env bash
set -euo pipefail

ILJARI_ROOT="${ILJARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SERVER_DIR="${ILJARI_ROOT}/server"
TEMPLATE="${SERVER_DIR}/nginx/staging.conf.template"
OUT="${SERVER_DIR}/staging/nginx.generated.conf"
ENV_FILE="${SERVER_DIR}/.env.staging"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source <(grep -E '^(STAGING_APP_HOST|STAGING_API_HOST)=' "${ENV_FILE}" || true)
  set +a
fi

export STAGING_APP_HOST="${STAGING_APP_HOST:-app.staging.iljari.local}"
export STAGING_API_HOST="${STAGING_API_HOST:-api.staging.iljari.local}"

mkdir -p "${SERVER_DIR}/staging"
sed \
  -e "s/\${STAGING_APP_HOST}/${STAGING_APP_HOST}/g" \
  -e "s/\${STAGING_API_HOST}/${STAGING_API_HOST}/g" \
  < "${TEMPLATE}" > "${OUT}"

echo "[staging] nginx config → ${OUT}"
