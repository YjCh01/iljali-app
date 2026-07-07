#!/usr/bin/env bash
# 토스 PG 키 → 서버 .env
# Usage: ./scripts/set_toss_keys_on_server.sh CLIENT_KEY SECRET_KEY [WEBHOOK_SECRET]
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/environments.env
source scripts/environments.env
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

CLIENT_KEY="${1:-}"
SECRET_KEY="${2:-}"
WEBHOOK_SECRET="${3:-}"

if [[ -z "${CLIENT_KEY}" || -z "${SECRET_KEY}" ]]; then
  echo "Usage: $0 TOSS_CLIENT_KEY TOSS_SECRET_KEY [TOSS_WEBHOOK_SECRET]" >&2
  exit 1
fi

iljari_ssh_init

iljari_ssh_run "bash -s" <<REMOTE
set -euo pipefail
ENV_FILE="/opt/iljari/server/.env"
cp "\$ENV_FILE" "\${ENV_FILE}.bak.\$(date +%Y%m%d%H%M%S)"
python3 - <<PY
from pathlib import Path
env_path = Path("/opt/iljari/server/.env")
text = env_path.read_text() if env_path.exists() else ""
updates = {
    "TOSS_CLIENT_KEY": "${CLIENT_KEY}",
    "TOSS_SECRET_KEY": "${SECRET_KEY}",
    "TOSS_WEBHOOK_SECRET": "${WEBHOOK_SECRET}",
    "PAYMENT_WEB_SUCCESS_URL": "https://iljari.app/payment-success",
    "PAYMENT_WEB_FAIL_URL": "https://iljari.app/payment-fail",
    "FREE_EXPOSURE_PROMO": "false",
}
lines = text.splitlines()
seen = set()
out = []
for line in lines:
    key = line.split("=", 1)[0].strip() if "=" in line else ""
    if key in updates:
        out.append(f"{key}={updates[key]}")
        seen.add(key)
    else:
        out.append(line)
for key, val in updates.items():
    if key not in seen:
        out.append(f"{key}={val}")
env_path.write_text("\\n".join(out).rstrip() + "\\n")
PY
cd /opt/iljari/server
docker compose up -d --build api
echo "[OK] API 재시작 완료"
grep -E '^TOSS_' "\$ENV_FILE" | sed 's/=.*/=***설정됨***/'
REMOTE

echo ""
curl -sS "https://api.iljari.app/health" | python3 -m json.tool 2>/dev/null | grep -E 'toss_|free_exposure' || true
echo ""
