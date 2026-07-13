#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/preflight_deploy.sh 2>/dev/null
exec ./scripts/preflight_deploy.sh
