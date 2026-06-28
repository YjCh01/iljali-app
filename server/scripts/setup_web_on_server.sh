#!/usr/bin/env bash
set -euo pipefail
SERVER_DIR="${ILJARI_SERVER_DIR:-/opt/iljari/server}"
WEB_DIR="${ILJARI_WEB_HOST_DIR:-/opt/iljari/web}"

echo "[setup] iljari.app edge nginx (:80)"
mkdir -p "${WEB_DIR}"/{web,seeker,corporate,admin,qc}

if [[ ! -f "${SERVER_DIR}/docker-compose.yml" ]]; then
  echo "ERROR: server 폴더 없음 — 맥에서 scp로 업로드"
  exit 1
fi

cd "${SERVER_DIR}"
export ILJARI_WEB_HOST_DIR="${WEB_DIR}"
docker compose up -d --build edge api

echo ""
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
cat <<'EOF'
========================================
  확인 (맥 브라우저)
========================================
  http://iljari.app/
  http://api.iljari.app:8000/health

  네이버 지도 URL: http://iljari.app
========================================
EOF
