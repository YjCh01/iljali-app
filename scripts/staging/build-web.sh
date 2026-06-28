#!/usr/bin/env bash
set -euo pipefail

ILJARI_ROOT="${ILJARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SERVER_DIR="${ILJARI_ROOT}/server"
ENV_FILE="${SERVER_DIR}/.env.staging"
WEB_OUT="${SERVER_DIR}/staging/web"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  set -a
  source <(grep -E '^(STAGING_APP_HOST|STAGING_API_HOST|ADMIN_API_KEY)=' "${ENV_FILE}" || true)
  set +a
fi

STAGING_API_HOST="${STAGING_API_HOST:-api.staging.iljari.local}"
STAGING_APP_HOST="${STAGING_APP_HOST:-app.staging.iljari.local}"
API_URL="https://${STAGING_API_HOST}"
ADMIN_KEY="${ADMIN_API_KEY:-staging-admin-change-me}"

cd "${ILJARI_ROOT}"
# shellcheck source=scripts/naver_flutter_defines.sh
source "scripts/naver_flutter_defines.sh"
naver_sync_flutter_defines || true

echo "[staging] flutter build web → ${WEB_OUT}"
flutter pub get

# shellcheck disable=SC2086
flutter build web --release \
  --dart-define=COMPLIANCE_API_URL="${API_URL}" \
  --dart-define=QC_MODE=false \
  --dart-define=CORPORATE_WEB_QC=true \
  --dart-define=ADMIN_API_KEY="${ADMIN_KEY}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}

rm -rf "${WEB_OUT}"
mkdir -p "${WEB_OUT}"
cp -R build/web/. "${WEB_OUT}/"

echo "[staging] Web artifact ready for https://${STAGING_APP_HOST}"
