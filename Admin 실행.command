#!/bin/bash
cd "$(dirname "$0")"
chmod +x run_admin.sh run_qc.sh run_web.sh scripts/naver_flutter_defines.sh 2>/dev/null
clear
echo "========================================"
echo "  일자리 — Admin 관리자 콘솔"
echo "  http://localhost:8081/#/admin"
echo "========================================"
echo ""
exec ./run_admin.sh
