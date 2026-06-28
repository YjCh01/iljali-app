#!/usr/bin/env bash
# 서버에서 실행 — nginx 80+8080, API 8000 기동
set -euo pipefail
SERVER_DIR="${ILJARI_SERVER_DIR:-/opt/iljari/server}"
WEB_DIR="${ILJARI_WEB_HOST_DIR:-/opt/iljari/web}"

echo "[fix] iljari server stack"
mkdir -p "${WEB_DIR}"/{web,seeker,corporate,admin,qc}
cd "${SERVER_DIR}"
export ILJARI_WEB_HOST_DIR="${WEB_DIR}"

# 구 compose 서비스명 web → edge 정리
docker compose stop web 2>/dev/null || true
docker compose rm -f web 2>/dev/null || true

docker compose up -d --build edge api db

echo ""
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "--- localhost ---"
curl -sf -o /dev/null -w "  :80/seeker/ → %{http_code}\n" http://127.0.0.1/seeker/ || echo "  :80 FAIL"
curl -sf -o /dev/null -w "  :8080/seeker/ → %{http_code}\n" http://127.0.0.1:8080/seeker/ || echo "  :8080 FAIL"
curl -sf -o /dev/null -w "  :8000/health → %{http_code}\n" http://127.0.0.1:8000/health || echo "  :8000 FAIL"
echo ""
cat <<'EOF'
========================================
  NCP ACG 인바운드 (콘솔에서 확인)
========================================
  TCP 22   SSH
  TCP 80   http://iljari.app/seeker/
  TCP 8080 (과도기, 나중에 제거 가능)
  TCP 8000 http://api.iljari.app:8000/health
  TCP 443  (HTTPS 나중에)

  맥 브라우저 (http 만, https 아님):
    http://iljari.app/seeker/
    http://iljari.app:8080/seeker/
========================================
EOF
