#!/usr/bin/env bash
# SSL(Let's Encrypt) + nginx — 실패해도 HTTP는 반드시 유지
set -uo pipefail

SERVER_DIR="/opt/iljari/server"
WEB_DIR="/opt/iljari/web"
EMAIL="${ILJARI_SSL_EMAIL:-admin@iljari.app}"
CERT="/etc/letsencrypt/live/iljari.app/fullchain.pem"
COMPOSE=(docker compose -f docker-compose.yml)
HTTP_COMPOSE=(docker compose -f docker-compose.yml -f docker-compose.http.yml)

cd "${SERVER_DIR}"
export ILJARI_WEB_HOST_DIR="${WEB_DIR}"
mkdir -p "${WEB_DIR}/.well-known/acme-challenge"

start_http() {
  echo "[ssl] HTTP nginx 기동 (사이트 복구)"
  rm -f docker-compose.override.yml
  # HTTP 모드: SSL conf 마운트 제거
  "${HTTP_COMPOSE[@]}" up -d --force-recreate edge api db
  sleep 2
}

start_https() {
  echo "[ssl] HTTPS nginx 기동"
  "${COMPOSE[@]}" up -d --force-recreate edge api db
  sleep 3
}

if ! command -v certbot >/dev/null 2>&1; then
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq certbot
fi

# 1) 무조건 HTTP 먼저 — cert 실패해도 사이트 살아있게
start_http

# CORS + Admin API 키 (웹 빌드와 동일)
ENV_FILE="${SERVER_DIR}/.env"
ADMIN_KEY="${ILJARI_ADMIN_API_KEY:-iljari-admin-dev-key}"
if [[ -f "${ENV_FILE}" ]]; then
  if grep -q '^CORS_ORIGINS=' "${ENV_FILE}"; then
    sed -i.bak 's|^CORS_ORIGINS=.*|CORS_ORIGINS=https://iljari.app,https://www.iljari.app,http://iljari.app,http://localhost:8082,http://127.0.0.1:8082|' "${ENV_FILE}"
  else
    echo 'CORS_ORIGINS=https://iljari.app,https://www.iljari.app,http://iljari.app,http://localhost:8082,http://127.0.0.1:8082' >> "${ENV_FILE}"
  fi
  if grep -q '^ADMIN_API_KEY=' "${ENV_FILE}"; then
    sed -i.bak "s|^ADMIN_API_KEY=.*|ADMIN_API_KEY=${ADMIN_KEY}|" "${ENV_FILE}"
  else
    echo "ADMIN_API_KEY=${ADMIN_KEY}" >> "${ENV_FILE}"
  fi
fi

SSL_OK=0
if [[ -f "${CERT}" ]]; then
  echo "[ssl] 기존 인증서 있음"
  SSL_OK=1
else
  echo "[ssl] 인증서 발급 (webroot, nginx 유지)"
  for attempt in 1 2 3 4 5; do
    if certbot certonly --webroot -w "${WEB_DIR}" \
      -d iljari.app -d www.iljari.app -d api.iljari.app \
      --non-interactive --agree-tos -m "${EMAIL}" \
      --preferred-challenges http; then
      SSL_OK=1
      break
    fi
    echo "[ssl] Let's Encrypt busy — ${attempt}/5, 45초 후 재시도..."
    sleep 45
  done
fi

if [[ "${SSL_OK}" -eq 1 && -f "${CERT}" ]]; then
  start_https
  docker exec server-edge-1 nginx -t
  echo ""
  echo "✅ https://iljari.app/"
  echo "✅ https://api.iljari.app/health"
else
  echo ""
  echo "⚠️  SSL 발급 실패 — HTTP는 동작 중:"
  echo "   http://iljari.app/"
  echo "   NCP ACG TCP 443 확인 후 도구_사이트완료.command 다시 실행"
  exit 0
fi

curl -sk -o /dev/null -w "local https web → %{http_code}\n" \
  --resolve iljari.app:443:127.0.0.1 https://iljari.app/ 2>/dev/null || true
