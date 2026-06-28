#!/usr/bin/env bash
# 웹 — server=배포+브라우저 · local=맥 chrome hot reload
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
source scripts/server_dev.sh

VARIANT="${1:?site|corporate|admin|seeker|qc}"

if iljari_is_local; then
  case "${VARIANT}" in
    site|seeker) exec ./run_seeker_web.sh ;;
    corporate) exec ./run_corporate_web.sh ;;
    admin) exec ./run_admin.sh ;;
    qc) exec ./run_qc.sh ;;
    *) exec ./run_web.sh ;;
  esac
fi

clear
iljari_print_env_banner
echo ""

DEPLOY_VARIANT="${VARIANT}"
[[ "${DEPLOY_VARIANT}" == "corporate" ]] && DEPLOY_VARIANT=site

./scripts/deploy_web_variant.sh "${DEPLOY_VARIANT}"

PUBLIC="$(iljari_resolve_web_base_url)/"
if [[ "${VARIANT}" == "admin" ]]; then
  PUBLIC="$(iljari_resolve_web_base_url)/admin/"
elif [[ "${VARIANT}" != "site" && "${VARIANT}" != "corporate" ]]; then
  PUBLIC="$(iljari_resolve_web_base_url)/${VARIANT}/"
fi

echo ""
echo "열기: ${PUBLIC}"
[[ "$(uname)" == "Darwin" ]] && open "${PUBLIC}"
read -r -p "Enter…" _ 2>/dev/null || true
