#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/gabia_dns_check.sh 2>/dev/null
exec ./scripts/gabia_dns_check.sh
