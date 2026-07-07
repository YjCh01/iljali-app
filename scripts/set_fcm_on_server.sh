#!/usr/bin/env bash
# Firebase 서비스계정 JSON → 서버 FCM_SERVICE_ACCOUNT_JSON
# Usage: ./scripts/set_fcm_on_server.sh /path/to/firebase-adminsdk.json
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/environments.env
source scripts/environments.env
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

JSON_PATH="${1:-}"
if [[ -z "${JSON_PATH}" || ! -f "${JSON_PATH}" ]]; then
  echo "Usage: $0 /path/to/firebase-service-account.json" >&2
  exit 1
fi

B64="$(python3 -c "import base64,sys; print(base64.b64encode(open(sys.argv[1],'rb').read()).decode())" "${JSON_PATH}")"

iljari_ssh_init

iljari_ssh_run "bash -s" <<REMOTE
set -euo pipefail
ENV_FILE="/opt/iljari/server/.env"
cp "\$ENV_FILE" "\${ENV_FILE}.bak.\$(date +%Y%m%d%H%M%S)"
python3 - <<PY
import base64, json
from pathlib import Path
raw = base64.b64decode("${B64}").decode()
info = json.loads(raw)
json_line = json.dumps(info, separators=(",", ":"))
env_path = Path("/opt/iljari/server/.env")
text = env_path.read_text() if env_path.exists() else ""
updates = {"FCM_SERVICE_ACCOUNT_JSON": json_line}
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
grep -E '^FCM_SERVICE_ACCOUNT_JSON=' "\$ENV_FILE" | sed 's/=.*/=***설정됨***/'
REMOTE

echo ""
echo "[확인]"
curl -sS "https://api.iljari.app/v1/notifications/config" 2>/dev/null | python3 -m json.tool 2>/dev/null || true
echo ""
