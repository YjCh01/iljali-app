#!/usr/bin/env bash
# Flutter web 빌드 (NCP 배포용 variant)
# Usage: ./scripts/build_web_ncp.sh [web|seeker|corporate|admin|qc]
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/naver_flutter_defines.sh
source scripts/naver_flutter_defines.sh
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh

VARIANT="${1:-web}"
API_URL="$(iljari_resolve_compliance_api_url)"
ADMIN_KEY="$(iljari_resolve_admin_api_key)"
OUT_DIR="${ILJARI_ROOT}/build/web-deploy/${VARIANT}"

BASE_HREF="/web/"
EXTRA_DEFINES=(
  "--dart-define=COMPLIANCE_API_URL=${API_URL}"
  "--dart-define=ADMIN_API_KEY=${ADMIN_KEY}"
)

case "${VARIANT}" in
  site)
    # 실서비스 — iljari.app/ (통합: 게이트웨이에서 개인/기업 선택)
    BASE_HREF="/"
    EXTRA_DEFINES+=(
      "--dart-define=QC_MODE=false"
    )
    ;;
  web)
    BASE_HREF="/web/"
    ;;
  seeker)
    # 개발·QC 전용 서브경로
    BASE_HREF="/seeker/"
    EXTRA_DEFINES+=(
      "--dart-define=QC_MODE=true"
      "--dart-define=INDIVIDUAL_ENTRY=true"
    )
    ;;
  corporate)
    BASE_HREF="/corporate/"
    EXTRA_DEFINES+=(
      "--dart-define=QC_MODE=false"
      "--dart-define=CORPORATE_WEB_QC=true"
    )
    ;;
  admin)
    BASE_HREF="/admin/"
    EXTRA_DEFINES+=(
      "--dart-define=ADMIN_ENTRY=true"
      "--dart-define=QC_MODE=true"
    )
    ;;
  qc)
    BASE_HREF="/qc/"
    EXTRA_DEFINES+=("--dart-define=QC_MODE=true")
    ;;
  *)
    echo "ERROR: unknown variant '${VARIANT}' (site|web|seeker|corporate|admin|qc)"
    exit 1
    ;;
esac

naver_sync_flutter_defines || true
chmod +x ./scripts/sync_web_icons.sh
./scripts/sync_web_icons.sh
flutter pub get

echo "[web] build variant=${VARIANT} base-href=${BASE_HREF} api=${API_URL}"
# shellcheck disable=SC2086
if ! flutter build web --release \
  --base-href="${BASE_HREF}" \
  "${EXTRA_DEFINES[@]}" \
  ${WEB_DEFINE} ${NAVER_DEFINE}; then
  echo "ERROR: flutter build web failed (variant=${VARIANT})" >&2
  exit 1
fi

rm -rf "${OUT_DIR}"
mkdir -p "${OUT_DIR}"
cp -R build/web/. "${OUT_DIR}/"
date > "${OUT_DIR}/.iljari_build_ok"
echo "[web] artifact → ${OUT_DIR}"
