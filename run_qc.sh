#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
WEB_PORT=8080
API_PORT=8000
ADMIN_KEY=qc-admin-dev-key

echo
echo "========================================"
echo "  iljari QC (server + Chrome, PG mock)"
echo "  API : http://127.0.0.1:${API_PORT}"
echo "  App : http://localhost:${WEB_PORT}"
echo "========================================"
echo

free_port() {
  local pids
  pids="$(lsof -ti :"$1" 2>/dev/null || true)"
  if [[ -n "${pids}" ]]; then
    kill -9 ${pids} 2>/dev/null || true
    sleep 1
  fi
}

free_port "${WEB_PORT}"
free_port "${API_PORT}"

if [[ ! -f server/.env ]]; then
  cp -f server/.env.example server/.env
fi

echo "[1/4] QC DB seed..."
(
  cd server
  uvicorn app.main:app --host 127.0.0.1 --port "${API_PORT}" &
  API_PID=$!
  sleep 3
  python scripts/seed_qc.py --seekers 1000 --jobs fixtures/jobs.example.json --wallet-brn 1000000001 --wallet-credits 30 || true
  kill "${API_PID}" 2>/dev/null || true
)

echo "[2/4] starting API..."
(
  cd server
  uvicorn app.main:app --host 127.0.0.1 --port "${API_PORT}" &
) 
sleep 2

echo "[3/4] flutter pub get..."
flutter pub get

echo "[4/4] Chrome QC..."
flutter run -d chrome --web-hostname=localhost --web-port="${WEB_PORT}" \
  --dart-define=COMPLIANCE_API_URL="http://127.0.0.1:${API_PORT}" \
  --dart-define=QC_MODE=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}"
