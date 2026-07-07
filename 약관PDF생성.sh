#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

echo "========================================"
echo "  약관 PDF 생성 (변호사 검토용)"
echo "========================================"
echo ""

dart run tool/generate_legal_pdfs.dart

echo ""
echo "출력: store/legal/pdf/*.pdf"
echo "변호사에게 이 폴더 ZIP 또는 PDF 전달 → 검토 후 피드백 주시면 반영"
read -r -p "Enter…" _
