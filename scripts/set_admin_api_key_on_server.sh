#!/usr/bin/env bash
# 어드민 API 키를 서버 .env에 저장하고 API 재시작
# Usage: ./scripts/set_admin_api_key_on_server.sh NEW_KEY
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/environments.env
source scripts/environments.env
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

NEW_KEY="${1:-}"
if [[ -z "${NEW_KEY}" ]]; then
  echo "Usage: $0 ADMIN_API_KEY" >&2
  exit 1
fi

NEW_KEY="$(echo -n "${NEW_KEY}" | tr -d '[:space:]')"

iljari_ssh_init

iljari_ssh_run "bash -s" <<REMOTE
set -euo pipefail
ENV_FILE="/opt/iljari/server/.env"
cp "\$ENV_FILE" "\${ENV_FILE}.bak.\$(date +%Y%m%d%H%M%S)"
python3 - <<PY
from pathlib import Path
env_path = Path("/opt/iljari/server/.env")
text = env_path.read_text() if env_path.exists() else ""
updates = {"ADMIN_API_KEY": "${NEW_KEY}"}
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
echo "[OK] ADMIN_API_KEY 서버 반영 + API 재시작"
grep -E '^ADMIN_API_KEY=' "\$ENV_FILE" | sed 's/=.*/=***설정됨***/'
REMOTE
