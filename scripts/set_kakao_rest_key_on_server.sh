#!/usr/bin/env bash
# Kakao REST API 키(주소 지오코딩)를 NCP 서버 .env에 넣고 API 재시작
# Usage:
#   ./scripts/set_kakao_rest_key_on_server.sh REST_API_KEY
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/environments.env
source scripts/environments.env
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

KAKAO_KEY="${1:-}"
if [[ -z "${KAKAO_KEY}" ]]; then
  echo "Usage: $0 KAKAO_REST_API_KEY" >&2
  exit 1
fi

# KOE101 방지 — 앞뒤 공백 제거
KAKAO_KEY="$(echo -n "${KAKAO_KEY}" | tr -d '[:space:]')"

if [[ ${#KAKAO_KEY} -lt 32 ]]; then
  echo "[경고] REST API 키가 32자 미만입니다. 잘린 키면 카카오 API가 거부(KOE101)합니다." >&2
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
    "KAKAO_REST_API_KEY": "${KAKAO_KEY}",
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
grep -E '^KAKAO_REST_API_KEY=' "\$ENV_FILE" | sed 's/=.*/=***설정됨***/'
REMOTE

echo ""
echo "[확인] https://api.iljari.app/health"
curl -sS "https://api.iljari.app/health" | python3 -m json.tool 2>/dev/null | grep -E 'juso_configured|kakao_geocode' || curl -sS "https://api.iljari.app/health"
echo ""
echo "[주소 검색 테스트] (Juso 키도 있으면 도로명+좌표)"
echo "  curl -s 'https://api.iljari.app/v1/addresses/search?q=송파구+오금로' | python3 -m json.tool | head -40"
echo ""
