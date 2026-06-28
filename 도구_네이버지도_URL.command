#!/bin/bash
cd "$(dirname "$0")"
chmod +x scripts/naver_ncp_urls.sh 2>/dev/null
exec ./scripts/naver_ncp_urls.sh
