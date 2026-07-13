#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/setup_testflight.sh 2>/dev/null
exec ./scripts/setup_testflight.sh
