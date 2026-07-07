#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/set_admin_ip_allowlist_on_server.sh

echo "========================================"
echo "  어드민 /admin/ IP 추가"
echo "========================================"
echo ""
MY_IP="$(curl -sS -m 10 https://api.ipify.org 2>/dev/null || true)"
[[ -n "${MY_IP}" ]] && echo "지금 이 맥 IP: ${MY_IP}"
echo ""
echo "추가할 IP (쉼표 구분). 전체 해제는 c 입력:"
read -r -p "> " INPUT

if [[ "${INPUT}" == "c" || "${INPUT}" == "C" ]]; then
  ./scripts/set_admin_ip_allowlist_on_server.sh --clear
else
  IFS=',' read -r -a IPS <<< "${INPUT}"
  ./scripts/set_admin_ip_allowlist_on_server.sh "${IPS[@]}"
fi

echo ""
read -r -p "Enter…" _
