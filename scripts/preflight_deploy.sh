#!/usr/bin/env bash
# 배포 전 로컬·원격 준비 상태 점검 (실패해도 exit 0 — 정보 출력용)
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
export ILJARI_ROOT="${ROOT}"

# shellcheck source=scripts/server_dev.sh
source scripts/server_dev.sh
# shellcheck source=scripts/iljari_ios_env.sh
source scripts/iljari_ios_env.sh

FAIL=0
WARN=0

check() {
  local label="$1"
  shift
  if "$@"; then
    echo "  ✓ ${label}"
  else
    echo "  ✗ ${label}"
    FAIL=$((FAIL + 1))
  fi
}

warn() {
  local label="$1"
  echo "  ⚠ ${label}"
  WARN=$((WARN + 1))
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  iljari 배포 preflight"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "[공통]"
check "flutter" command -v flutter >/dev/null
check "pubspec.yaml" test -f pubspec.yaml
check "server/app" test -d server/app

API_URL="$(iljari_resolve_compliance_api_url 2>/dev/null || echo "")"
if [[ -n "${API_URL}" ]]; then
  code="$(curl -sk -o /dev/null -w '%{http_code}' --connect-timeout 8 "${API_URL%/}/health" 2>/dev/null || echo 0)"
  if [[ "${code}" == "200" ]]; then
    echo "  ✓ API health (${API_URL%/}/health → 200)"
  else
    echo "  ✗ API health (${API_URL%/}/health → HTTP ${code})"
    FAIL=$((FAIL + 1))
  fi
else
  warn "COMPLIANCE_API_URL 미설정"
fi

echo ""
echo "[Android]"
# shellcheck source=scripts/ensure_java.sh
source scripts/ensure_java.sh
if iljari_ensure_java --quiet 2>/dev/null && java -version >/dev/null 2>&1; then
  echo "  ✓ Java $( "${JAVA_HOME}/bin/java" -version 2>&1 | head -1 )"
else
  echo "  ✗ Java 없음 — 도구_Java설치.command (로그인 시 java.com 메시지도 사라짐)"
  FAIL=$((FAIL + 1))
fi

echo ""
echo "[iOS / TestFlight]"
if [[ "$(uname)" != "Darwin" ]]; then
  echo "  — macOS 아님 (iOS 빌드 건너뜀)"
else
  set +e
  iljari_ios_preflight
  ios_rc=$?
  set -e
  if [[ "${ios_rc}" == 1 ]]; then
    FAIL=$((FAIL + 1))
  elif [[ "${ios_rc}" == 2 ]]; then
    WARN=$((WARN + 1))
  fi
  if command -v pod >/dev/null 2>&1; then
    echo "  ✓ CocoaPods $(pod --version 2>/dev/null)"
  else
    echo "  ✗ CocoaPods 없음 — 도구_CocoaPods설치.command"
    FAIL=$((FAIL + 1))
  fi
fi

echo ""
echo "[스토어 자동 업로드]"
if [[ -f fastlane/play-store-key.json ]]; then
  echo "  ✓ Play Console key (fastlane/play-store-key.json)"
else
  echo "  — Play Console key 없음 (AAB/APK 빌드만)"
fi
if iljari_ios_has_upload_credentials 2>/dev/null; then
  echo "  ✓ TestFlight 업로드 credentials"
else
  reason="$(iljari_ios_upload_skip_reason)"
  [[ -n "${reason}" ]] && echo "  — TestFlight: ${reason}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [[ "${FAIL}" -gt 0 ]]; then
  echo "  결과: ${FAIL}건 실패, ${WARN}건 주의 — 위 ✗ 항목 수정 후 배포"
elif [[ "${WARN}" -gt 0 ]]; then
  echo "  결과: 배포 가능 (TestFlight 업로드는 setup 후)"
else
  echo "  결과: 배포 준비 OK"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
