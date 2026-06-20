#!/bin/bash
cd "$(dirname "$0")"
chmod +x run_web.sh run_qc.sh scripts/naver_flutter_defines.sh 네이버키_설정.sh 2>/dev/null
clear
echo "========================================"
echo "  일자리 — QC (서버 + mock PG + Chrome)"
echo "  http://localhost:8080"
echo "========================================"
echo ""
exec ./run_qc.sh
