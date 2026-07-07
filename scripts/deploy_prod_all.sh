#!/usr/bin/env bash
# 실서비스 한방 배포 — API + 웹(site·admin) + 앱 빌드(·스토어)
# Usage:
#   ./scripts/deploy_prod_all.sh              # API + 웹 + 앱
#   ./scripts/deploy_prod_all.sh --api-only
#   ./scripts/deploy_prod_all.sh --web-only
#   ./scripts/deploy_prod_all.sh --app-only
#   ./scripts/deploy_prod_all.sh --no-app     # API+웹만 (앱 빌드 생략)
#   ./scripts/deploy_prod_all.sh --store-upload # 앱 빌드 후 fastlane 실패 시 exit 1
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh
# shellcheck source=scripts/iljari_ssh.sh
source scripts/iljari_ssh.sh

DO_API=1
DO_WEB=1
DO_APP=1
STORE_UPLOAD_STRICT=0
for arg in "$@"; do
  case "${arg}" in
    --api-only) DO_WEB=0; DO_APP=0 ;;
    --web-only) DO_API=0; DO_APP=0 ;;
    --app-only) DO_API=0; DO_WEB=0 ;;
    --no-app) DO_APP=0 ;;
    --store-upload) STORE_UPLOAD_STRICT=1 ;;
    -h|--help)
      echo "Usage: $0 [--api-only | --web-only | --app-only | --no-app | --store-upload]"
      exit 0
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      exit 1
      ;;
  esac
done

API_URL="$(iljari_resolve_compliance_api_url)"
WEB_BASE="$(iljari_resolve_web_base_url)"
REMOTE_DIR="${ILJARI_SERVER_DIR_REMOTE:-/opt/iljari/server}"
WEB_DIR="${ILJARI_REMOTE_WEB_DIR:-/opt/iljari/web}"

clear
echo ""
echo "========================================"
echo "  iljari 실서비스 — 한방 배포"
if [[ "${DO_API}" == 1 && "${DO_WEB}" == 1 && "${DO_APP}" == 1 ]]; then
  echo "  ① API  → ${API_URL}"
  echo "  ② Web  → ${WEB_BASE}/ + /admin/"
  echo "  ③ App  → AAB + APK (+ iOS·스토어 credentials 있으면 업로드)"
elif [[ "${DO_API}" == 1 && "${DO_WEB}" == 0 && "${DO_APP}" == 0 ]]; then
  echo "  API only → ${API_URL}"
elif [[ "${DO_WEB}" == 1 && "${DO_API}" == 0 && "${DO_APP}" == 0 ]]; then
  echo "  Web only → ${WEB_BASE}/ + /admin/"
elif [[ "${DO_APP}" == 1 && "${DO_API}" == 0 && "${DO_WEB}" == 0 ]]; then
  echo "  App only → releases/ + 스토어(설정 시)"
else
  [[ "${DO_API}" == 1 ]] && echo "  API → ${API_URL}"
  [[ "${DO_WEB}" == 1 ]] && echo "  Web → ${WEB_BASE}/ + /admin/"
  [[ "${DO_APP}" == 1 ]] && echo "  App → AAB + APK (+ 스토어)"
fi
echo "========================================"
echo ""
echo "NCP SSH 비밀번호는 최초 1회만 묻습니다 (키 등록 시 생략)."
echo ""

iljari_ssh_init

FAILED=0

deploy_api() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [API] FastAPI 배포"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  local tar="/tmp/iljari-server-$(date +%s).tar.gz"
  local remote_tar="/tmp/iljari-server-deploy.tar.gz"

  echo "[API 1/3] tarball..."
  iljari_tar_create "${tar}" \
    --exclude='.venv' \
    --exclude='__pycache__' \
    --exclude='*.pyc' \
    --exclude='*.db' \
    --exclude='.env' \
    -C "${ILJARI_ROOT}/server" .

  echo "[API 2/3] upload..."
  iljari_ssh_upload "${remote_tar}" "${tar}"

  echo "[API 3/3] extract + docker rebuild..."
  iljari_ssh_run bash -s <<REMOTE
set -euo pipefail
REMOTE_DIR="${REMOTE_DIR}"
REMOTE_TAR="${remote_tar}"
ENV_BAK="/tmp/iljari-server-env.bak"
if [[ -f "\${REMOTE_DIR}/.env" ]]; then
  cp "\${REMOTE_DIR}/.env" "\${ENV_BAK}"
fi
mkdir -p "\${REMOTE_DIR}"
if tar --warning=no-unknown-keyword -xzf "\${REMOTE_TAR}" -C "\${REMOTE_DIR}" 2>/dev/null; then
  :
else
  tar -xzf "\${REMOTE_TAR}" -C "\${REMOTE_DIR}"
fi
if [[ -f "\${ENV_BAK}" ]]; then
  cp "\${ENV_BAK}" "\${REMOTE_DIR}/.env"
fi
cd "\${REMOTE_DIR}"
export ILJARI_WEB_HOST_DIR="${WEB_DIR}"
docker compose up -d --build api
docker compose up -d edge db 2>/dev/null || true
$(iljari_remote_api_wait_block)
echo "[server] API deploy OK"
REMOTE

  rm -f "${tar}"

  if ! iljari_verify_public_api_health "${API_URL}" 90; then
    FAILED=1
  fi
}

deploy_web_variant() {
  local variant="$1"
  local tar="/tmp/iljari-web-${variant}.tar.gz"
  local public
  if [[ "${variant}" == "site" ]]; then
    public="${WEB_BASE}/"
  else
    public="${WEB_BASE}/${variant}/"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [Web] ${variant} → ${public}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  echo "[Web 1/4] Flutter build..."
  if ! ./scripts/build_web_ncp.sh "${variant}"; then
    echo "❌ Flutter build failed — ${variant} (업로드 생략)"
    return 1
  fi
  if [[ ! -f "build/web-deploy/${variant}/.iljari_build_ok" ]]; then
    echo "❌ 빌드 산출물 없음 — ${variant} (업로드 생략)"
    return 1
  fi

  echo "[Web 2/4] tar..."
  iljari_tar_create "${tar}" -C "build/web-deploy/${variant}" .

  echo "[Web 3/4] upload + server unpack..."
  iljari_ssh_upload "${tar}" "${tar}"
  iljari_ssh_upload /opt/iljari/server/scripts/deploy_variant_on_server.sh \
    "${ILJARI_ROOT}/server/scripts/deploy_variant_on_server.sh"
  iljari_ssh_run "chmod +x /opt/iljari/server/scripts/deploy_variant_on_server.sh"
  iljari_ssh_run "ILJARI_ADMIN_API_KEY='$(iljari_resolve_admin_api_key)' bash /opt/iljari/server/scripts/deploy_variant_on_server.sh ${variant} ${tar}"

  echo "[Web 4/4] verify..."
  sleep 2
  local code
  code="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 25 "${public}" 2>/dev/null || echo 0)"
  if [[ ! "${code}" =~ ^[23] ]]; then
    echo "❌ ${public} → HTTP ${code}"
    FAILED=1
  else
    echo "✅ ${public} → HTTP ${code}"
  fi
}

deploy_app() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  [App] 실서비스 빌드 (+ 스토어)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  chmod +x ./scripts/build_prod_app.sh
  local app_args=()
  [[ "${STORE_UPLOAD_STRICT}" == 1 ]] && app_args+=(--upload)
  if [[ ${#app_args[@]} -eq 0 ]]; then
    ./scripts/build_prod_app.sh || return 1
  else
    ./scripts/build_prod_app.sh "${app_args[@]}" || return 1
  fi
  return 0
}

if [[ "${DO_API}" == 1 ]]; then
  deploy_api || FAILED=1
fi

if [[ "${DO_WEB}" == 1 ]]; then
  for variant in site admin; do
    deploy_web_variant "${variant}" || FAILED=1
  done
fi

if [[ "${DO_APP}" == 1 ]]; then
  deploy_app || FAILED=1
fi

echo ""
echo "========================================"
if [[ "${FAILED}" == 0 ]]; then
  echo "  ✅ 한방 배포 완료"
  [[ "${DO_API}" == 1 ]] && echo "  API  : ${API_URL}/health"
  [[ "${DO_WEB}" == 1 ]] && echo "  Site : ${WEB_BASE}/"
  [[ "${DO_WEB}" == 1 ]] && echo "  Admin: ${WEB_BASE}/admin/"
  [[ "${DO_APP}" == 1 ]] && echo "  App  : releases/iljari-android-latest.apk"
  [[ "${DO_APP}" == 1 ]] && echo "         android/.../app-release.aab"
  if [[ "$(uname)" == "Darwin" && "${DO_WEB}" == 1 ]]; then
    open "${WEB_BASE}/"
  fi
else
  echo "  ⚠️  일부 단계 실패 — 위 로그 확인"
  [[ "${DO_API}" == 1 ]] && echo "  (API·웹이 ✅면 서비스·카카오 로그인 테스트는 가능)"
  echo "  Android Java 오류 → 도구_Java설치.command"
  echo "  iOS CocoaPods/SSL 오류 → 도구_CocoaPods설치.command (CA 인증서 자동 설치)"
  echo "  SSL/nginx: 도구_사이트완료.command"
fi
echo "========================================"
echo ""
read -r -p "Enter 키로 창 닫기…" _

exit "${FAILED}"
