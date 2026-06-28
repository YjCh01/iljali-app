#!/usr/bin/env bash
# PEM → 공개키 출력 (NCP VNC에서 authorized_keys에 등록용)
set -euo pipefail

KEY="${1:-$HOME/Projects Keys/iljari app/iljari-key.pem}"

if [[ ! -f "${KEY}" ]]; then
  echo "ERROR: 키 없음 — ${KEY}"
  exit 1
fi

echo "========================================"
echo "  SSH 공개키 (아래 한 줄 전체 복사)"
echo "========================================"
ssh-keygen -y -f "${KEY}"
echo ""
echo "NCP VNC 콘솔 → 서버 접속 후 붙여넣기:"
echo ""
cat <<'EOF'
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# 맨 아래에 공개키 한 줄 붙여넣기 → 저장 (Ctrl+O, Enter, Ctrl+X)
chmod 600 ~/.ssh/authorized_keys
EOF
echo ""
echo "그다음 맥에서 테스트:"
echo "  ssh -i \"${KEY}\" root@211.188.56.77"
echo "========================================"
