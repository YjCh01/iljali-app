#!/usr/bin/env bash
# nginx 설정(web-variants + admin-ip) 서버 동기화 + edge reload
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/environments.env
source scripts/environments.env
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

iljari_ssh_init

iljari_ssh_upload "${ILJARI_ROOT}/server/nginx/web-variants.conf" \
  /opt/iljari/server/nginx/web-variants.conf
iljari_ssh_upload "${ILJARI_ROOT}/server/nginx/admin-ip-allow.conf" \
  /opt/iljari/server/nginx/admin-ip-allow.conf
iljari_ssh_upload "${ILJARI_ROOT}/server/docker-compose.yml" \
  /opt/iljari/server/docker-compose.yml

iljari_ssh_run "bash -s" <<'REMOTE'
set -euo pipefail
cd /opt/iljari/server
docker compose up -d edge
docker compose exec edge nginx -t
docker compose exec edge nginx -s reload
echo "[OK] nginx 동기화 + reload"
REMOTE
