#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/diagnose_ncp.sh 2>/dev/null
exec ./scripts/diagnose_ncp.sh
