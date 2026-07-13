#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/check_testflight.sh 2>/dev/null
exec ./scripts/check_testflight.sh
