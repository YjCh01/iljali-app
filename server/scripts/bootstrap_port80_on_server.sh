#!/usr/bin/env bash
# 서버 SSH 안에서만 실행 (맥 경로 없음)
# curl -s ... | bash  또는 붙여넣기
set -euo pipefail

SERVER_DIR="/opt/iljari/server"
WEB_DIR="/opt/iljari/web"

echo "[1] 디렉터리"
mkdir -p "${SERVER_DIR}/nginx" "${WEB_DIR}"/{web,seeker,corporate,admin,qc}

echo "[2] nginx 설정"
cat > "${SERVER_DIR}/nginx/production.conf" <<'NGX'
server {
    listen 80 default_server;
    server_name www.iljari.app iljari.app app.iljari.app;
    client_max_body_size 25m;
    include /etc/nginx/snippets/web-variants.conf;
}
NGX

cat > "${SERVER_DIR}/nginx/api-proxy.conf" <<'NGX'
server {
    listen 80;
    server_name api.iljari.app;
    client_max_body_size 25m;
    location / {
        proxy_pass http://api:8000;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGX

cat > "${SERVER_DIR}/nginx/web-variants.conf" <<'NGX'
location / {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /index.html;
}
location /web/ {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /web/index.html;
}
location /seeker/ {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /seeker/index.html;
}
location /corporate/ {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /corporate/index.html;
}
location /admin/ {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /admin/index.html;
}
location /qc/ {
    root /usr/share/nginx/html;
    try_files $uri $uri/ /qc/index.html;
}
NGX

echo "[3] docker-compose (80 + 8080 + API 8000)"
if [[ ! -f "${SERVER_DIR}/docker-compose.yml" ]]; then
  echo "ERROR: ${SERVER_DIR} 없음 — 맥에서 scp 로 server 폴더 업로드 필요"
  exit 1
fi

# API 8000 외부 노출 유지 + edge nginx
cat > "${SERVER_DIR}/docker-compose.override.yml" <<'YML'
services:
  api:
    ports:
      - "8000:8000"
  edge:
    image: nginx:1.27-alpine
    ports:
      - "80:80"
      - "8080:80"
    volumes:
      - /opt/iljari/web:/usr/share/nginx/html:ro
      - ./nginx/production.conf:/etc/nginx/conf.d/10-web.conf:ro
      - ./nginx/api-proxy.conf:/etc/nginx/conf.d/20-api.conf:ro
      - ./nginx/web-variants.conf:/etc/nginx/snippets/web-variants.conf:ro
    depends_on:
      - api
    restart: unless-stopped
YML

cd "${SERVER_DIR}"
docker compose stop web 2>/dev/null || true
docker compose rm -f web 2>/dev/null || true
export ILJARI_WEB_HOST_DIR="${WEB_DIR}"
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d --build edge api db

echo ""
echo "[4] 상태"
docker ps --format 'table {{.Names}}\t{{.Ports}}'
echo ""
curl -sf -o /dev/null -w "localhost:80/seeker/ → %{http_code}\n" http://127.0.0.1/seeker/ || echo "localhost:80 FAIL"
curl -sf -o /dev/null -w "localhost:8080/seeker/ → %{http_code}\n" http://127.0.0.1:8080/seeker/ || echo "localhost:8080 FAIL"
echo ""
echo "맥 브라우저: http://iljari.app/"
