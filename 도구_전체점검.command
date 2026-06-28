#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/full_audit.sh server/scripts/fix_port80.sh 2>/dev/null
exec ./scripts/full_audit.sh
