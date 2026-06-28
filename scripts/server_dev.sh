#!/usr/bin/env bash
# shellcheck shell=bash
# Shared FastAPI dev server helpers — auto venv + python -m uvicorn

ILJARI_ROOT="${ILJARI_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
ILJARI_SERVER_DIR="${ILJARI_ROOT}/server"
ILJARI_SERVER_VENV="${ILJARI_SERVER_DIR}/.venv"
ILJARI_SERVER_PYTHON=""

iljari_ensure_server_env() {
  if [[ ! -d "${ILJARI_SERVER_DIR}" ]]; then
    echo "ERROR: server directory not found at ${ILJARI_SERVER_DIR}"
    exit 1
  fi

  if [[ -x "${ILJARI_SERVER_VENV}/bin/python" ]]; then
    ILJARI_SERVER_PYTHON="${ILJARI_SERVER_VENV}/bin/python"
  elif command -v python3 >/dev/null 2>&1; then
    ILJARI_SERVER_PYTHON="$(command -v python3)"
  elif command -v python >/dev/null 2>&1; then
    ILJARI_SERVER_PYTHON="$(command -v python)"
  else
    echo "ERROR: python3 not found. Install Python 3.11+ (brew install python)."
    exit 1
  fi

  if ! "${ILJARI_SERVER_PYTHON}" -m uvicorn --help >/dev/null 2>&1; then
    echo "[server] uvicorn missing — creating venv at server/.venv ..."
    if [[ ! -x "${ILJARI_SERVER_VENV}/bin/python" ]]; then
      "${ILJARI_SERVER_PYTHON}" -m venv "${ILJARI_SERVER_VENV}"
    fi
    ILJARI_SERVER_PYTHON="${ILJARI_SERVER_VENV}/bin/python"
    "${ILJARI_SERVER_PYTHON}" -m pip install -q --upgrade pip
    "${ILJARI_SERVER_PYTHON}" -m pip install -q -r "${ILJARI_SERVER_DIR}/requirements.txt"
    echo "[server] dependencies installed"
  fi
}

iljari_start_api_server() {
  local port="${1:-8000}"
  iljari_ensure_server_env
  (
    cd "${ILJARI_SERVER_DIR}"
    "${ILJARI_SERVER_PYTHON}" -m uvicorn app.main:app \
      --host 127.0.0.1 --port "${port}" &
  )
}

iljari_seed_qc_sample() {
  iljari_ensure_server_env
  (
    cd "${ILJARI_SERVER_DIR}"
    "${ILJARI_SERVER_PYTHON}" scripts/seed_qc.py \
      --seekers 100 \
      --jobs fixtures/jobs.example.json \
      --wallet-brn 1000000001 \
      --wallet-credits 30 \
      --visual-scenario
  )
}

iljari_seed_qc_visual_scenario() {
  iljari_ensure_server_env
  (
    cd "${ILJARI_SERVER_DIR}"
    "${ILJARI_SERVER_PYTHON}" scripts/seed_qc.py \
      --seekers 100 \
      --jobs fixtures/jobs.example.json \
      --wallet-brn 1000000001 \
      --wallet-credits 30 \
      --visual-scenario
  )
}

iljari_curl_api() {
  local curl_args=(-sf)
  if [[ "${ILJARI_CURL_INSECURE:-}" == "1" ]]; then
    curl_args=(-skf)
  fi
  curl "${curl_args[@]}" "$@"
}

# NCP docker compose — API 컨테이너 healthy + edge nginx reload (heredoc에 삽입)
iljari_remote_api_wait_block() {
  cat <<'REMOTE_API_WAIT'
echo "[server] waiting for API container..."
ready=0
for i in $(seq 1 45); do
  if docker compose exec -T api curl -sf http://localhost:8000/health >/dev/null 2>&1; then
    echo "[server] API container healthy"
    ready=1
    break
  fi
  sleep 2
done
if [[ "${ready}" != "1" ]]; then
  echo "[server] ERROR: API container did not become healthy"
  docker compose ps
  docker compose logs api --tail 60
  exit 1
fi
docker compose exec edge nginx -s reload 2>/dev/null || docker compose up -d --force-recreate edge
echo "[server] waiting for edge /health..."
for i in $(seq 1 20); do
  if curl -sf http://127.0.0.1/health >/dev/null 2>&1; then
    curl -sf http://127.0.0.1/health | head -c 200
    echo ""
    echo "[server] edge proxy OK"
    break
  fi
  sleep 2
done
REMOTE_API_WAIT
}

iljari_verify_public_api_health() {
  local api_url="${1:-$(iljari_resolve_compliance_api_url)}"
  local max_wait="${2:-90}"
  export ILJARI_CURL_INSECURE=1
  echo "[API] public health check (up to ${max_wait}s)..."
  if iljari_wait_api_health "${api_url}" "${max_wait}"; then
    echo "✅ API health → ${api_url}/health"
    return 0
  fi
  echo "❌ API health → timeout (${api_url}/health)"
  echo "   재시작 직후 nginx 502일 수 있음 — 1~2분 후: curl -sk ${api_url}/health"
  return 1
}

iljari_admin_ensure_sample_jobs() {
  local api_url="${1:-$(iljari_resolve_compliance_api_url)}"
  local admin_key="${2:-$(iljari_resolve_admin_api_key)}"
  iljari_ensure_server_env
  if ! iljari_curl_api -H "X-Admin-Api-Key: ${admin_key}" \
    "${api_url}/v1/admin/ops/stats" >/dev/null 2>&1; then
    echo "[server] admin stats unavailable — skip sample seed"
    return 1
  fi
  local job_count employer_count
  job_count="$(
    iljari_curl_api -H "X-Admin-Api-Key: ${admin_key}" \
      "${api_url}/v1/admin/ops/stats" 2>/dev/null \
      | "${ILJARI_SERVER_PYTHON}" -c "import sys,json; print(json.load(sys.stdin).get('job_posts',0))" \
      2>/dev/null || echo 0
  )"
  employer_count="$(
    iljari_curl_api -H "X-Admin-Api-Key: ${admin_key}" \
      "${api_url}/v1/admin/ops/stats" 2>/dev/null \
      | "${ILJARI_SERVER_PYTHON}" -c "import sys,json; print(json.load(sys.stdin).get('corporates',0))" \
      2>/dev/null || echo 0
  )"
  if [[ "${job_count}" == "0" ]]; then
    if iljari_use_local_api; then
      echo "[server] no job posts — seeding local sample data..."
      iljari_seed_qc_sample
    else
      echo "[server] remote API has no job posts — run: ./scripts/seed_ncp_server.sh"
    fi
  elif [[ "${employer_count}" == "0" ]]; then
    if iljari_use_local_api; then
      echo "[server] no employer members — seeding sample employers..."
      (
        cd "${ILJARI_SERVER_DIR}"
        "${ILJARI_SERVER_PYTHON}" -c "
from app.database import SessionLocal, Base, engine, ensure_qc_member_schema
from app.services.admin_ops_service import seed_employers
Base.metadata.create_all(bind=engine)
ensure_qc_member_schema()
db = SessionLocal()
try:
    print(seed_employers(db))
finally:
    db.close()
"
      )
    else
      echo "[server] remote API has no employers — run: ./scripts/seed_ncp_server.sh"
    fi
  fi
}

# macOS → Linux 배포 tar (Apple provenance/xattr 메타데이터 제외)
# Linux에서 "tar: Ignoring unknown extended header keyword ..." 경고 방지
iljari_tar_create() {
  local archive="$1"
  shift
  COPYFILE_DISABLE=1 tar --format ustar -czf "${archive}" "$@"
}

# Linux 서버 압축 해제 — 구형 tar에 macOS 메타가 남아 있어도 경고만 억제
iljari_tar_extract_on_linux() {
  local archive="$1"
  local dest="$2"
  if tar --warning=no-unknown-keyword -xzf "${archive}" -C "${dest}" 2>/dev/null; then
    return 0
  fi
  tar -xzf "${archive}" -C "${dest}"
}

# shellcheck source=scripts/api_target.sh
source "${ILJARI_ROOT}/scripts/api_target.sh"
