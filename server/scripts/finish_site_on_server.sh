#!/usr/bin/env bash
# 서버 — site 배포 + HTTPS
set -euo pipefail

SERVER_DIR="/opt/iljari/server"
WEB_DIR="/opt/iljari/web"
TAR="${1:-/tmp/iljari-web-site.tar.gz}"

mkdir -p "${SERVER_DIR}/nginx" "${WEB_DIR}"

if [[ -f "${TAR}" && "${TAR}" != "/dev/null" ]]; then
  echo "[1] 웹 배포 → ${WEB_DIR}/"
  tar -xzf "${TAR}" -C "${WEB_DIR}"
else
  echo "[1] 웹 파일 유지"
fi

echo "[2] SSL + nginx"
bash "${SERVER_DIR}/scripts/setup_ssl_on_server.sh"
