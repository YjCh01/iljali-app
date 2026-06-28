#!/usr/bin/env bash
# iljari.app 전체 배포 (HTTPS + site 빌드)
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
source scripts/server_dev.sh

KEY="${ILJARI_SSH_KEY}"
TARGET="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
TAR="/tmp/iljari-web-site.tar.gz"
PUBLIC="$(iljari_resolve_web_base_url)/"
API_HEALTH="$(iljari_resolve_compliance_api_url)/health"
NGINX_DIR="${ILJARI_ROOT}/server/nginx"

SSH_BASE=(-o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
ASKPASS=""
PASS=""

cleanup() { [[ -n "${ASKPASS}" && -f "${ASKPASS}" ]] && rm -f "${ASKPASS}"; }
trap cleanup EXIT

iljari_ensure_ssh() {
  if [[ -f "${KEY}" ]] && ssh -i "${KEY}" -o IdentitiesOnly=yes -o BatchMode=yes "${SSH_BASE[@]}" \
    "${TARGET}" 'echo ok' >/dev/null 2>&1; then
    SSH_CMD=(ssh -i "${KEY}" -o IdentitiesOnly=yes "${SSH_BASE[@]}")
    echo "[SSH] 키 인증 OK"
    return 0
  fi
  echo "[SSH] NCP 서버 root 비밀번호"
  if [[ "$(uname)" == "Darwin" ]]; then
    PASS="$(osascript -e 'display dialog "NCP 서버 root 비밀번호:" default answer "" with hidden answer buttons {"OK"} default button 1' -e 'text returned of result' 2>/dev/null || true)"
  fi
  [[ -z "${PASS:-}" ]] && read -r -s -p "NCP root 비밀번호: " PASS && echo ""
  ASKPASS="$(mktemp)"; chmod 700 "${ASKPASS}"
  printf '%s\n' '#!/bin/sh' "exec printf '%s' \"${PASS}\"" > "${ASKPASS}"; chmod 700 "${ASKPASS}"
  export SSH_ASKPASS="${ASKPASS}" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}"
  SSH_CMD=(ssh "${SSH_BASE[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no)
  "${SSH_CMD[@]}" "${TARGET}" 'echo ok' >/dev/null
  echo "[SSH] OK"
}

upload() {
  local dest="$1" src="$2"
  "${SSH_CMD[@]}" "${TARGET}" "mkdir -p $(dirname "${dest}")"
  "${SSH_CMD[@]}" "${TARGET}" "cat > ${dest}" < "${src}"
}

echo "========================================"
echo "  iljari.app 배포"
echo "  ${PUBLIC}"
echo "========================================"
iljari_ensure_ssh

echo "[1/6] Flutter site 빌드 (API=${API_HEALTH%/health})..."
./scripts/build_web_ncp.sh site

echo "[2/6] tar..."
COPYFILE_DISABLE=1 tar -czf "${TAR}" -C build/web-deploy/site .
ls -lh "${TAR}"

echo "[3/6] 서버 설정 업로드..."
upload /opt/iljari/server/docker-compose.yml "${ILJARI_ROOT}/server/docker-compose.yml"
upload /opt/iljari/server/docker-compose.http.yml "${ILJARI_ROOT}/server/docker-compose.http.yml"
upload /opt/iljari/server/nginx/bootstrap-http.conf "${NGINX_DIR}/bootstrap-http.conf"
upload /opt/iljari/server/nginx/web-variants.conf "${NGINX_DIR}/web-variants.conf"
for f in production.conf production-ssl.conf api-proxy.conf api-proxy-ssl.conf; do
  upload "/opt/iljari/server/nginx/${f}" "${NGINX_DIR}/${f}"
done
upload /opt/iljari/server/scripts/setup_ssl_on_server.sh "${ILJARI_ROOT}/server/scripts/setup_ssl_on_server.sh"
upload /opt/iljari/server/scripts/finish_site_on_server.sh "${ILJARI_ROOT}/server/scripts/finish_site_on_server.sh"
"${SSH_CMD[@]}" "${TARGET}" "chmod +x /opt/iljari/server/scripts/*.sh"

echo "[4/6] 웹 업로드..."
"${SSH_CMD[@]}" "${TARGET}" "cat > ${TAR}" < "${TAR}"

echo "[5/6] 서버 적용 (SSL + nginx)..."
"${SSH_CMD[@]}" "${TARGET}" "bash /opt/iljari/server/scripts/finish_site_on_server.sh ${TAR}"

echo "[6/6] 실서비스 URL 점검..."
./scripts/verify_all_prod_urls.sh || true

[[ "$(uname)" == "Darwin" ]] && open "${PUBLIC}" 2>/dev/null || true
