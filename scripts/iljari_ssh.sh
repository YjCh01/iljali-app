#!/usr/bin/env bash
# NCP SSH (키 → 비밀번호 fallback)
set -euo pipefail

ILJARI_SSH_CMD=()

iljari_ssh_init() {
  local key="${ILJARI_SSH_KEY:-}"
  local target="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
  local base=(-o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

  if [[ -f "${key}" ]] && ssh -i "${key}" -o IdentitiesOnly=yes -o BatchMode=yes "${base[@]}" \
    "${target}" 'echo ok' >/dev/null 2>&1; then
    ILJARI_SSH_CMD=(ssh -i "${key}" -o IdentitiesOnly=yes "${base[@]}")
    return 0
  fi

  echo "[SSH] NCP root 비밀번호"
  local pass=""
  if [[ "$(uname)" == "Darwin" ]]; then
    pass="$(osascript -e 'display dialog "NCP 서버 root 비밀번호:" default answer "" with hidden answer buttons {"OK"} default button 1' -e 'text returned of result' 2>/dev/null || true)"
  fi
  [[ -z "${pass}" ]] && read -r -s -p "NCP root 비밀번호: " pass && echo ""

  local askpass
  askpass="$(mktemp)"; chmod 700 "${askpass}"
  printf '%s\n' '#!/bin/sh' "exec printf '%s' \"${pass}\"" > "${askpass}"; chmod 700 "${askpass}"
  export SSH_ASKPASS="${askpass}" SSH_ASKPASS_REQUIRE=force DISPLAY="${DISPLAY:-:0}"

  ILJARI_SSH_CMD=(ssh "${base[@]}" -o PreferredAuthentications=password -o PubkeyAuthentication=no)
  "${ILJARI_SSH_CMD[@]}" "${target}" 'echo ok' >/dev/null
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
