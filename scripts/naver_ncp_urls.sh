#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
clear
cat <<'EOF'
========================================
  네이버 NCP — Web URL (+ 추가)

  https://iljari.app
  http://iljari.app
  http://localhost
  http://127.0.0.1

  Android: kr.co.iljari.app
  iOS:     kr.co.iljari.app
========================================
EOF
read -r -p "Enter…" _
