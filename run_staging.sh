#!/usr/bin/env bash
# Staging HTTPS stack: Postgres + API + nginx (self-signed TLS).
# Local: add hosts → 127.0.0.1 app.staging.iljari.local api.staging.iljari.local
set -euo pipefail

cd "$(dirname "$0")"
export ILJARI_ROOT="$(pwd)"

SKIP_BUILD=0
SKIP_SEED=0
DETACH=1

for arg in "$@"; do
  case "${arg}" in
    --skip-build) SKIP_BUILD=1 ;;
    --skip-seed) SKIP_SEED=1 ;;
    --foreground) DETACH=0 ;;
    -h|--help)
      echo "Usage: ./run_staging.sh [--skip-build] [--skip-seed] [--foreground]"
      exit 0
      ;;
  esac
done

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker not found. Install Docker Desktop for staging HTTPS."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "ERROR: docker compose plugin not found."
  exit 1
fi

ENV_STAGING="server/.env.staging"
if [[ ! -f "${ENV_STAGING}" ]]; then
  echo "[staging] Creating ${ENV_STAGING} from example ..."
  cp -f server/staging/env.example "${ENV_STAGING}"
fi

# shellcheck disable=SC1090
set -a
source <(grep -E '^(STAGING_APP_HOST|STAGING_API_HOST)=' "${ENV_STAGING}" || true)
set +a
STAGING_APP_HOST="${STAGING_APP_HOST:-app.staging.iljari.local}"
STAGING_API_HOST="${STAGING_API_HOST:-api.staging.iljari.local}"
export STAGING_APP_HOST STAGING_API_HOST

chmod +x scripts/staging/*.sh
scripts/staging/init-certs.sh
scripts/staging/render-nginx-conf.sh

if [[ "${SKIP_BUILD}" -eq 0 ]]; then
  scripts/staging/build-web.sh
else
  mkdir -p server/staging/web
  if [[ ! -f server/staging/web/index.html ]]; then
    echo "ERROR: --skip-build but server/staging/web/index.html missing. Run without --skip-build once."
    exit 1
  fi
fi

COMPOSE_ARGS=( -f docker-compose.staging.yml up --build )
if [[ "${DETACH}" -eq 1 ]]; then
  COMPOSE_ARGS+=( -d )
fi

(
  cd server
  docker compose "${COMPOSE_ARGS[@]}"
)

if [[ "${DETACH}" -eq 1 ]]; then
  echo "[staging] Waiting for API health via nginx ..."
  for _ in $(seq 1 40); do
    if curl -skf "https://${STAGING_API_HOST}/health" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  if curl -skf "https://${STAGING_API_HOST}/health" >/dev/null 2>&1; then
    echo "[staging] API OK: https://${STAGING_API_HOST}/health"
  else
    echo "[staging] WARN: API health check failed — docker logs may help"
  fi

  if [[ "${SKIP_SEED}" -eq 0 ]]; then
  # shellcheck source=scripts/server_dev.sh
    source scripts/server_dev.sh
    iljari_ensure_server_env
    ADMIN_KEY="$(grep '^ADMIN_API_KEY=' "${ENV_STAGING}" | cut -d= -f2- | tr -d '\r' || echo staging-admin-change-me)"
    ILJARI_CURL_INSECURE=1 iljari_admin_ensure_sample_jobs "https://${STAGING_API_HOST}" "${ADMIN_KEY}" || true
  fi
fi

cat <<EOF

========================================
  iljari Staging (HTTPS)
========================================
  /etc/hosts (if not set):
    127.0.0.1 ${STAGING_APP_HOST} ${STAGING_API_HOST}

  App : https://${STAGING_APP_HOST}
  API : https://${STAGING_API_HOST}
  Toss webhook: https://${STAGING_API_HOST}/v1/payments/webhook/toss

  Self-signed cert — browser에서 1회 신뢰 필요
  Logs: cd server && docker compose -f docker-compose.staging.yml logs -f
  Stop: cd server && docker compose -f docker-compose.staging.yml down
========================================
EOF
