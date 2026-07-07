#!/usr/bin/env bash
# Google OAuth 키를 NCP 서버 .env에 넣고 API 재시작
# Usage:
#   ./scripts/set_google_oauth_on_server.sh CLIENT_ID CLIENT_SECRET
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/environments.env
source scripts/environments.env
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

CLIENT_ID="${1:-}"
CLIENT_SECRET="${2:-}"
if [[ -z "${CLIENT_ID}" || -z "${CLIENT_SECRET}" ]]; then
  echo "Usage: $0 GOOGLE_OAUTH_CLIENT_ID GOOGLE_OAUTH_CLIENT_SECRET" >&2
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
    "GOOGLE_OAUTH_CLIENT_ID": "${CLIENT_ID}",
    "GOOGLE_OAUTH_CLIENT_SECRET": "${CLIENT_SECRET}",
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
grep -E '^GOOGLE_OAUTH_CLIENT_ID=' "\$ENV_FILE"
grep -E '^GOOGLE_OAUTH_CLIENT_SECRET=' "\$ENV_FILE" | sed 's/=.*/=***설정됨***/'
REMOTE

echo ""
echo "[확인] https://api.iljari.app/v1/auth/social/status"
sleep 3
curl -sS "https://api.iljari.app/v1/auth/social/status" || true
echo ""
