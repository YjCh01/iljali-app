#!/usr/bin/env bash
# 스토어 업로드 전 로컬 점검 (콘솔 업로드는 수동)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"

FAIL=0
ok() { echo "  ✓ $1"; }
warn() { echo "  ⚠ $1"; }
die() { echo "  ✗ $1"; FAIL=1; }

echo "== store preflight =="

# Bundle / package
if grep -q 'applicationId = "kr.co.iljari.app"' android/app/build.gradle.kts; then
  ok "Android applicationId kr.co.iljari.app"
else
  die "Android applicationId 확인 필요"
fi

if grep -q 'PRODUCT_BUNDLE_IDENTIFIER = kr.co.iljari.app' ios/Runner.xcodeproj/project.pbxproj; then
  ok "iOS bundle ID kr.co.iljari.app"
else
  die "iOS bundle ID 확인 필요"
fi

# Legal assets
LEGAL_COUNT="$(find store/legal -maxdepth 1 -name '[0-9]*.md' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${LEGAL_COUNT}" -ge 9 ]]; then
  ok "약관 markdown ${LEGAL_COUNT}종"
else
  die "약관 markdown 부족 (${LEGAL_COUNT}/9)"
fi

PDF_COUNT="$(find store/legal/pdf -name '*.pdf' 2>/dev/null | wc -l | tr -d ' ')"
if [[ "${PDF_COUNT}" -ge 9 ]]; then
  ok "약관 PDF ${PDF_COUNT}종"
else
  warn "PDF 재생성: dart run tool/generate_legal_pdfs.dart (${PDF_COUNT}/9)"
fi

# Release artifacts (optional)
if [[ -f android/app/build/outputs/bundle/release/app-release.aab ]]; then
  ok "Android AAB 존재"
else
  warn "AAB 없음 — ./scripts/build_release.sh 실행"
fi

if [[ -d build/web ]] && [[ -f build/web/index.html ]]; then
  ok "Web build 존재"
else
  warn "Web build 없음"
fi

# Listing docs
for f in store/listing/play_store.md store/listing/app_store.md store/README.md; do
  if [[ -f "${f}" ]]; then ok "${f}"; else die "${f} 없음"; fi
done

echo
if [[ "${FAIL}" -eq 0 ]]; then
  echo "Preflight passed (warnings는 선택 항목)."
  exit 0
else
  echo "Preflight failed."
  exit 1
fi
