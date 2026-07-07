#!/usr/bin/env bash
# assets/icon/app_icon_1024.png → web/favicon + PWA icons
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${ROOT}/assets/icon/app_icon_1024.png"
WEB="${ROOT}/web"

if [[ ! -f "${SRC}" ]]; then
  echo "[icons] skip — ${SRC} 없음" >&2
  exit 0
fi

mkdir -p "${WEB}/icons"
sips -z 32 32 "${SRC}" --out "${WEB}/favicon.png" >/dev/null
sips -z 192 192 "${SRC}" --out "${WEB}/icons/Icon-192.png" >/dev/null
sips -z 512 512 "${SRC}" --out "${WEB}/icons/Icon-512.png" >/dev/null
sips -z 192 192 "${SRC}" --out "${WEB}/icons/Icon-maskable-192.png" >/dev/null
sips -z 512 512 "${SRC}" --out "${WEB}/icons/Icon-maskable-512.png" >/dev/null
echo "[icons] web favicon + PWA ← app_icon_1024.png"
