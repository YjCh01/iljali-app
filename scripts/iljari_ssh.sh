#!/usr/bin/env bash
# NCP SSH (키 → 비밀번호 fallback, ControlMaster로 비밀번호 1회만)
set -euo pipefail

ILJARI_SSH_CMD=()
ILJARI_SSH_CONTROL=""

iljari_ssh_cleanup() {
  if [[ -n "${ILJARI_SSH_CONTROL}" ]]; then
    local target="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
    ssh -o ControlPath="${ILJARI_SSH_CONTROL}" -O exit "${target}" 2>/dev/null || true
  fi
}

iljari_ssh_init() {
  local key="${ILJARI_SSH_KEY:-}"
  local target="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
  local base=(-o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

  if [[ -f "${key}" ]] && ssh -i "${key}" -o IdentitiesOnly=yes -o BatchMode=yes "${base[@]}" \
    "${target}" 'echo ok' >/dev/null 2>&1; then
    echo "[SSH] 키 인증 OK"
    ILJARI_SSH_CMD=(ssh -i "${key}" -o IdentitiesOnly=yes "${base[@]}")
    return 0
  fi

  if [[ -f "${key}" ]]; then
    echo "[SSH] 키 인증 실패"
  fi
  echo "[SSH] 아래에 root 비밀번호 입력 (도구_SSH접속과 동일)"
  echo ""

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"
  ILJARI_SSH_CONTROL="${HOME}/.ssh/iljari-ncp-%r@%h:%p"
  trap iljari_ssh_cleanup EXIT

  local master_opts=(
    -o PreferredAuthentications=password
    -o PubkeyAuthentication=no
    -o ControlMaster=yes
    -o "ControlPath=${ILJARI_SSH_CONTROL}"
    -o ControlPersist=300
  )

  # 터미널에서 직접 입력 — osascript/SSH_ASKPASS 사용 안 함
  ssh "${base[@]}" "${master_opts[@]}" "${target}" 'echo ok'

  echo ""
  echo "[SSH] 비밀번호 OK — 배포 계속"
  ILJARI_SSH_CMD=(
    ssh "${base[@]}" -o ControlPath="${ILJARI_SSH_CONTROL}" -o ControlMaster=no
  )
}

iljari_ssh_target() { echo "${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"; }

iljari_ssh_upload() {
  local dest="$1" src="$2"
  "${ILJARI_SSH_CMD[@]}" "$(iljari_ssh_target)" "mkdir -p $(dirname "${dest}")"
  "${ILJARI_SSH_CMD[@]}" "$(iljari_ssh_target)" "cat > ${dest}" < "${src}"
}

iljari_ssh_run() {
  "${ILJARI_SSH_CMD[@]}" "$(iljari_ssh_target)" "$@"
}
