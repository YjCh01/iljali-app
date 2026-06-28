#!/usr/bin/env bash
# 실서버 Let's Encrypt — nginx 컨테이너 앞에서 1회 실행
set -euo pipefail

ILJARI_ROOT="${ILJARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
ENV_FILE="${ILJARI_ROOT}/server/.env.staging"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "ERROR: ${ENV_FILE} 없음 — server/staging/env.example 복사 후 도메인 설정"
  exit 1
fi

# shellcheck disable=SC1090
set -a
source <(grep -E '^(STAGING_APP_HOST|STAGING_API_HOST)=' "${ENV_FILE}" || true)
set +a

APP_HOST="${STAGING_APP_HOST:?STAGING_APP_HOST required}"
API_HOST="${STAGING_API_HOST:?STAGING_API_HOST required}"
EMAIL="${CERTBOT_EMAIL:-iljariapp@gmail.com}"
CERT_DIR="${ILJARI_ROOT}/server/staging/certs"

mkdir -p "${CERT_DIR}"

echo "[certbot] Obtaining certs for ${APP_HOST} and ${API_HOST} ..."
docker run --rm -it \
  -v "${CERT_DIR}:/etc/letsencrypt" \
  -v "${CERT_DIR}:/var/lib/letsencrypt" \
  -p 80:80 \
  certbot/certbot certonly --standalone \
  --agree-tos -m "${EMAIL}" \
  -d "${APP_HOST}" -d "${API_HOST}"

# nginx expects fullchain.pem / privkey.pem
LIVE_DIR="${CERT_DIR}/live/${APP_HOST}"
if [[ -f "${LIVE_DIR}/fullchain.pem" ]]; then
  cp -f "${LIVE_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem"
  cp -f "${LIVE_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem"
  echo "[certbot] Certs linked to ${CERT_DIR}/fullchain.pem"
else
  echo "[certbot] WARN: expected ${LIVE_DIR}/fullchain.pem — check certbot output"
fi

echo "[certbot] Renew cron example:"
echo "  0 3 * * * docker run --rm -v ${CERT_DIR}:/etc/letsencrypt certbot/certbot renew && cd ${ILJARI_ROOT}/server && docker compose -f docker-compose.staging.yml exec nginx nginx -s reload"
