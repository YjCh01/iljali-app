#!/usr/bin/env bash
# site(통합) + admin 실서비스 배포 — /corporate/ 는 루트 SPA와 동일
set -euo pipefail
cd "$(dirname "$0")/.."
for v in site admin; do
  echo ""
  echo "========== ${v} =========="
  ./scripts/deploy_web_variant.sh "${v}"
done
echo ""
echo "✅ 웹 실서비스 배포 완료 (통합 iljari.app)"
echo "   https://iljari.app/          ← 구직 지도 (로그인 시 개인/기업 선택)"
echo "   https://iljari.app/admin/"
