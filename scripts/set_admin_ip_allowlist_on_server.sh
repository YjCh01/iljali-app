#!/usr/bin/env bash
# /admin/ 경로 IP 허용 목록 설정
# Usage:
#   ./scripts/set_admin_ip_allowlist_on_server.sh 1.2.3.4 [IP2 ...]
#   ./scripts/set_admin_ip_allowlist_on_server.sh --clear
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"

MODE="set"
IPS=()
for arg in "$@"; do
  if [[ "${arg}" == "--clear" ]]; then
    MODE="clear"
  else
    IPS+=("${arg}")
  fi
done

ALLOW_FILE="${ILJARI_ROOT}/server/nginx/admin-ip-allow.conf"

if [[ "${MODE}" == "clear" ]]; then
  cat > "${ALLOW_FILE}" <<'EOF'
# 어드민 IP 제한 없음 — 모든 IP에서 /admin/ 접속 가능
EOF
  echo "[local] IP 제한 해제 파일 작성"
elif [[ ${#IPS[@]} -eq 0 ]]; then
  echo "Usage: $0 IP [IP2 ...]  또는  $0 --clear" >&2
  exit 1
else
  {
    echo "# iljari admin IP allowlist — $(date '+%Y-%m-%d %H:%M')"
    for ip in "${IPS[@]}"; do
      ip="$(echo -n "${ip}" | tr -d '[:space:]')"
      [[ -n "${ip}" ]] && echo "allow ${ip};"
    done
    echo "deny all;"
  } > "${ALLOW_FILE}"
  echo "[local] 허용 IP: ${IPS[*]}"
fi

chmod +x scripts/sync_admin_nginx_to_server.sh
./scripts/sync_admin_nginx_to_server.sh
