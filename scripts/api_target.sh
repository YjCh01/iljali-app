#!/usr/bin/env bash
# shellcheck shell=bash
# 환경 해석 — server(도메인) vs local(맥)

ILJARI_ENV_FILE="${ILJARI_ENV_FILE:-${ILJARI_ROOT}/scripts/environments.env}"
if [[ -f "${ILJARI_ENV_FILE}" ]]; then
  # shellcheck source=scripts/environments.env
  source "${ILJARI_ENV_FILE}"
fi

# legacy remote_api.env
ILJARI_API_CONFIG="${ILJARI_ROOT}/scripts/remote_api.env"
if [[ -f "${ILJARI_API_CONFIG}" ]]; then
  # shellcheck source=scripts/remote_api.env
  source "${ILJARI_API_CONFIG}"
fi

iljari_is_local() {
  [[ "${ILJARI_ENV:-server}" == "local" ]] ||
    [[ "${ILJARI_API_MODE:-}" == "local" ]] ||
    [[ "${ILJARI_FORCE_LOCAL_API:-}" == "1" ]]
}

iljari_use_local_api() { iljari_is_local; }

iljari_resolve_compliance_api_url() {
  local port="${1:-8000}"
  local device_hint="${2:-}"

  [[ -n "${COMPLIANCE_API_URL:-}" ]] && { echo "${COMPLIANCE_API_URL}"; return; }
  [[ -n "${COMPLIANCE_API_URL_OVERRIDE:-}" ]] && { echo "${COMPLIANCE_API_URL_OVERRIDE}"; return; }

  if iljari_is_local; then
    if [[ "${device_hint}" == *"emulator"* ]]; then
      echo "http://10.0.2.2:${port}"
    else
      echo "${ILJARI_LOCAL_API_URL:-http://127.0.0.1:8000}"
    fi
    return
  fi
  echo "${ILJARI_API_URL:-https://api.iljari.app}"
}

iljari_resolve_web_base_url() {
  [[ -n "${ILJARI_REMOTE_WEB_URL_OVERRIDE:-}" ]] && { echo "${ILJARI_REMOTE_WEB_URL_OVERRIDE%/}"; return; }
  if iljari_is_local; then
    local p="${ILJARI_LOCAL_WEB_PORT:-8082}"
    echo "http://localhost:${p}"
    return
  fi
  echo "${ILJARI_WEB_URL:-https://iljari.app}"
}

iljari_resolve_admin_api_key() {
  local key_file="${ILJARI_ADMIN_KEY_FILE:-${HOME}/Projects Keys/iljari app/iljari-admin-api-key.txt}"
  if [[ -f "${key_file}" ]]; then
    local k
    k="$(head -n 1 "${key_file}" | tr -d '[:space:]')"
    if [[ -n "${k}" ]]; then
      echo "${k}"
      return 0
    fi
  fi
  echo "${ADMIN_API_KEY:-${ILJARI_ADMIN_API_KEY:-iljari-admin-dev-key}}"
}

iljari_wait_api_health() {
  local api_url="$1"
  local max_wait="${2:-90}"
  local i=0
  while [[ "${i}" -lt "${max_wait}" ]]; do
    if iljari_curl_api "${api_url}/health" >/dev/null 2>&1; then
      echo "[API] healthy — ${api_url}"
      return 0
    fi
    sleep 2
    i=$((i + 2))
  done
  echo "ERROR: API health check failed — ${api_url}/health"
  return 1
}

iljari_wait_api_admin_stats() {
  local api_url="$1"
  local admin_key="$2"
  local max_wait="${3:-90}"
  local i=0
  while [[ "${i}" -lt "${max_wait}" ]]; do
    if iljari_curl_api -H "X-Admin-Api-Key: ${admin_key}" \
      "${api_url}/v1/admin/ops/stats" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
    i=$((i + 2))
  done
  echo "ERROR: admin stats unavailable — ${api_url}"
  return 1
}

iljari_ensure_api_ready() {
  local api_url="$1"
  local port="${2:-8000}"

  if iljari_is_local; then
    echo "[env] local — API localhost:${port}"
    if lsof -ti :"${port}" >/dev/null 2>&1; then
      if iljari_wait_api_health "http://127.0.0.1:${port}" 10; then
        return 0
      fi
      echo "[API] stale process on ${port}, restarting..."
      local pids
      pids="$(lsof -ti :"${port}" 2>/dev/null || true)"
      [[ -n "${pids}" ]] && kill -9 ${pids} 2>/dev/null || true
      sleep 1
    fi
    iljari_start_api_server "${port}"
    sleep 2
    iljari_wait_api_health "http://127.0.0.1:${port}"
    return $?
  fi

  echo "[env] server — ${api_url}"
  iljari_wait_api_health "${api_url}"
}

iljari_seed_qc_if_local() {
  local api_port="${1:-8000}"
  if ! iljari_is_local; then
    echo "[env] server — QC 데이터는 NCP PostgreSQL (./scripts/seed_ncp_server.sh)"
    return 0
  fi
  iljari_ensure_server_env
  (
    cd "${ILJARI_SERVER_DIR}"
    "${ILJARI_SERVER_PYTHON}" -m uvicorn app.main:app --host 127.0.0.1 --port "${api_port}" &
    API_PID=$!
    sleep 3
    "${ILJARI_SERVER_PYTHON}" scripts/seed_qc.py \
      --seekers "${ILJARI_QC_SEEKERS:-100}" \
      --jobs fixtures/jobs.example.json \
      --wallet-brn 1000000001 \
      --wallet-credits 30 \
      --visual-scenario || true
    kill "${API_PID}" 2>/dev/null || true
  )
}

iljari_print_env_banner() {
  if iljari_is_local; then
    echo "  환경     : local (맥 개발 — ILJARI_ENV=local)"
  else
    echo "  환경     : server (iljari.app)"
  fi
  echo "  API      : $(iljari_resolve_compliance_api_url)"
  echo "  Web      : $(iljari_resolve_web_base_url)"
}

iljari_print_api_banner() { iljari_print_env_banner; }

iljari_ssh_preflight() {
  local key="${ILJARI_SSH_KEY}"
  local target="${ILJARI_SSH_USER}@${ILJARI_SSH_HOST}"
  if [[ ! -f "${key}" ]]; then
    echo "ERROR: SSH 키 없음 — ${key}"
    echo "  → ./한번에배포.command"
    return 1
  fi
  if ssh -i "${key}" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=12 \
    "${target}" 'echo ok' >/dev/null 2>&1; then
    echo "[SSH] OK"
    return 0
  fi
  echo "ERROR: SSH 키 실패 → ./한번에배포.command (비밀번호)"
  return 1
}

iljari_web_port_preflight() {
  local base
  base="$(iljari_resolve_web_base_url)"
  if iljari_curl_api --connect-timeout 5 -o /dev/null "${base}/" 2>/dev/null; then
    echo "[Web] ${base} OK"
  else
    echo "WARN: ${base} — NCP ACG TCP 80 · edge 컨테이너 확인"
  fi
  return 0
}
