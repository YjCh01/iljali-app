#!/usr/bin/env bash
# NCP 서버 콘솔(VNC/SSH)에서 붙여넣기 — HTTPS + nginx
# 맥 scp 실패할 때 서버에서 직접 실행
set -euo pipefail
SERVER_DIR="/opt/iljari/server"
WEB_DIR="/opt/iljari/web"
mkdir -p "${SERVER_DIR}/nginx" "${SERVER_DIR}/scripts" "${WEB_DIR}"

# docker-compose + nginx 는 맥에서 scp 한 번 필요. 없으면 안내.
if [[ ! -f "${SERVER_DIR}/docker-compose.yml" ]]; then
  echo "ERROR: ${SERVER_DIR} 없음 — 맥에서 server/ 폴더 scp 먼저"
  exit 1
fi

if [[ -f "${SERVER_DIR}/scripts/setup_ssl_on_server.sh" ]]; then
  bash "${SERVER_DIR}/scripts/setup_ssl_on_server.sh"
else
  echo "ERROR: setup_ssl_on_server.sh 없음 — 맥에서 도구_사이트완료.command 실행"
  exit 1
fi
