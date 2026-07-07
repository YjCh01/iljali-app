#!/usr/bin/env bash
# NCP 서버 대화형 SSH (키 → 비밀번호)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/environments.env
source "${ROOT}/scripts/environments.env"

KEY="${ILJARI_SSH_KEY}"
TARGET="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
SSH_OPTS=(-o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

echo "========================================"
echo "  일자리 NCP SSH"
echo "  서버: ${TARGET}"
echo "========================================"

if [[ -f "${KEY}" ]]; then
  echo "[키] ${KEY}"
  if ssh -i "${KEY}" -o IdentitiesOnly=yes -o BatchMode=yes "${SSH_OPTS[@]}" \
    "${TARGET}" 'echo ok' >/dev/null 2>&1; then
    echo "[접속] 키 인증"
    exec ssh -i "${KEY}" -o IdentitiesOnly=yes "${SSH_OPTS[@]}" "${TARGET}"
  fi
  echo "[접속] 키 실패 — root 비밀번호 입력"
  exec ssh "${SSH_OPTS[@]}" "${TARGET}"
fi

echo "ERROR: SSH 키 없음 — ${KEY}"
echo "도구_SSH공개키출력.command 로 공개키 등록 후 다시 시도하세요."
exit 1
