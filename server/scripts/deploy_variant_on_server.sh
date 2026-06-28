#!/usr/bin/env bash
# 서버 — 웹 variant 압축 해제 + nginx reload
set -euo pipefail
VARIANT="${1:?variant}"
TAR="${2:?tar}"
WEB_DIR="${ILJARI_WEB_HOST_DIR:-/opt/iljari/web}"
SERVER_DIR="${ILJARI_SERVER_DIR:-/opt/iljari/server}"

if [[ "${VARIANT}" == "site" ]]; then
  mkdir -p "${WEB_DIR}"
  if tar --warning=no-unknown-keyword -xzf "${TAR}" -C "${WEB_DIR}" 2>/dev/null; then
    :
  else
    tar -xzf "${TAR}" -C "${WEB_DIR}"
  fi
  MARKER="${WEB_DIR}/index.html"
else
  mkdir -p "${WEB_DIR}/${VARIANT}"
  if tar --warning=no-unknown-keyword -xzf "${TAR}" -C "${WEB_DIR}/${VARIANT}" 2>/dev/null; then
    :
  else
    tar -xzf "${TAR}" -C "${WEB_DIR}/${VARIANT}"
  fi
  MARKER="${WEB_DIR}/${VARIANT}/index.html"
fi

[[ -f "${MARKER}" ]] || { echo "ERROR: 배포 실패 — ${MARKER} 없음"; exit 1; }

[[ -f "${MARKER}" ]] || { echo "ERROR: 배포 실패 — ${MARKER} 없음"; exit 1; }

ENV_FILE="${SERVER_DIR}/.env"
ADMIN_KEY="${ILJARI_ADMIN_API_KEY:-iljari-admin-dev-key}"
if [[ -f "${ENV_FILE}" ]]; then
  if grep -q '^ADMIN_API_KEY=' "${ENV_FILE}"; then
    sed -i.bak "s|^ADMIN_API_KEY=.*|ADMIN_API_KEY=${ADMIN_KEY}|" "${ENV_FILE}"
  else
    echo "ADMIN_API_KEY=${ADMIN_KEY}" >> "${ENV_FILE}"
  fi
fi

cd "${SERVER_DIR}"
export ILJARI_WEB_HOST_DIR="${WEB_DIR}"
docker compose up -d --force-recreate api 2>/dev/null || true
docker compose exec edge nginx -s reload 2>/dev/null \
  || docker compose up -d edge api db

if [[ "${VARIANT}" == "site" ]]; then
  curl -sf -o /dev/null http://127.0.0.1/ || true
else
  curl -sf -o /dev/null "http://127.0.0.1/${VARIANT}/" || true
fi
echo "[server] OK — ${VARIANT}"
