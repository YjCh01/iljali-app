#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
chmod +x scripts/check_service_health.sh 2>/dev/null
exec ./scripts/check_service_health.sh
