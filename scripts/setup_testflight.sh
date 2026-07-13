#!/usr/bin/env bash
# TestFlight 업로드용 Apple 인증·서명 1회 설정
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
export ILJARI_ROOT="${ROOT}"

# shellcheck source=scripts/iljari_ios_env.sh
source scripts/iljari_ios_env.sh

ENV_FILE="$(iljari_ios_env_file)"
EXAMPLE="${ROOT}/fastlane/.env.example"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TestFlight 설정 (1회)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

XCODE_TEAM="$(iljari_ios_team_from_xcode || true)"
if [[ -n "${XCODE_TEAM}" ]]; then
  echo "Xcode 프로젝트 Team ID: ${XCODE_TEAM}"
else
  echo "Xcode Team ID를 찾지 못했습니다 — ios/Runner.xcworkspace 에서 Team을 먼저 선택하세요."
fi
echo ""

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${EXAMPLE}" "${ENV_FILE}"
  echo "fastlane/.env 생성됨"
fi

iljari_ios_load_env

DEFAULT_TEAM="${APPLE_TEAM_ID:-${XCODE_TEAM:-}}"
echo "※ Team ID = 10자리 영숫자 (예: ${XCODE_TEAM:-JR36AGC7R9}) — Apple ID 이메일 아님"
read -r -p "Apple Developer 팀 ID · Enter=아래 값 사용 [${DEFAULT_TEAM}]: " TEAM_IN
if [[ -n "${TEAM_IN}" ]]; then
  APPLE_TEAM_ID="${TEAM_IN}"
elif [[ -n "${DEFAULT_TEAM}" ]]; then
  APPLE_TEAM_ID="${DEFAULT_TEAM}"
fi

if [[ "${APPLE_TEAM_ID}" == *"@"* ]]; then
  echo ""
  echo "❌ 이메일이 아니라 Team ID(10자)를 입력하세요. Xcode에 표시된 값: ${XCODE_TEAM:-JR36AGC7R9}"
  exit 1
fi
if [[ ! "${APPLE_TEAM_ID}" =~ ^[A-Z0-9]{10}$ ]]; then
  echo ""
  echo "❌ Team ID 형식 오류 — 10자리 영대문자+숫자 (현재: ${APPLE_TEAM_ID})"
  echo "   Xcode Team 또는 developer.apple.com → Membership"
  exit 1
fi

echo ""
echo "TestFlight 업로드 인증 (App Store Connect):"
echo "  1) API Key (.p8) — 권장, CI·자동 업로드에 적합"
echo "  2) Apple ID + 앱 전용 비밀번호"
read -r -p "선택 [1/2] (기본 1): " AUTH_MODE
AUTH_MODE="${AUTH_MODE:-1}"

if [[ "${AUTH_MODE}" == "1" ]]; then
  echo ""
  echo "App Store Connect → 사용자 및 액세스 → 통합 → App Store Connect API → 키 생성"
  read -r -p "Key ID [${ASC_KEY_ID:-}]: " KEY_ID_IN
  read -r -p "Issuer ID [${ASC_ISSUER_ID:-}]: " ISSUER_IN
  read -r -p ".p8 파일 경로 [${ASC_KEY_PATH:-}]: " KEY_PATH_IN
  [[ -n "${KEY_ID_IN}" ]] && ASC_KEY_ID="${KEY_ID_IN}"
  [[ -n "${ISSUER_IN}" ]] && ASC_ISSUER_ID="${ISSUER_IN}"
  [[ -n "${KEY_PATH_IN}" ]] && ASC_KEY_PATH="${KEY_PATH_IN}"
  if [[ -n "${ASC_KEY_PATH:-}" && -f "${ASC_KEY_PATH}" && "${ASC_KEY_PATH}" != "${ROOT}/fastlane/"* ]]; then
    dest="${ROOT}/fastlane/$(basename "${ASC_KEY_PATH}")"
    cp -f "${ASC_KEY_PATH}" "${dest}"
    ASC_KEY_PATH="${dest}"
    echo "키 복사: ${dest}"
  fi
  if [[ -z "${ASC_KEY_ID:-}" || -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_PATH:-}" || ! -f "${ASC_KEY_PATH}" ]]; then
    echo ""
    echo "⚠️  API Key 정보가 불완전합니다. 나중에 다시 실행하거나 방법 2(Apple ID)를 사용하세요."
  fi
else
  read -r -p "Apple ID (FASTLANE_USER) [${FASTLANE_USER:-}]: " USER_IN
  read -r -s -p "앱 전용 비밀번호 (appleid.apple.com → 앱 전용): " PASS_IN
  echo ""
  [[ -n "${USER_IN}" ]] && FASTLANE_USER="${USER_IN}"
  [[ -n "${PASS_IN}" ]] && FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="${PASS_IN}"
fi

cat > "${ENV_FILE}" <<EOF
APPLE_TEAM_ID=${APPLE_TEAM_ID}
ASC_KEY_ID=${ASC_KEY_ID:-}
ASC_ISSUER_ID=${ASC_ISSUER_ID:-}
ASC_KEY_PATH=${ASC_KEY_PATH:-}
FASTLANE_USER=${FASTLANE_USER:-}
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}
EOF

echo ""
echo "✅ fastlane/.env 저장됨 (Team: ${APPLE_TEAM_ID})"
echo ""

IDENTITIES="$(iljari_ios_signing_identity_count)"
IDENTITIES="${IDENTITIES:-0}"
if [[ "${IDENTITIES}" == 0 ]]; then
  echo "⚠️  Mac 키체인에 iOS 서명 인증서가 없습니다."
  echo "   1) Xcode → Settings → Accounts → Apple ID 추가"
  echo "   2) ios/Runner.xcworkspace → Runner → Signing & Capabilities"
  echo "      · Team: ${APPLE_TEAM_ID} · Automatically manage signing ✓"
  echo "   3) 완료 후 ./scripts/upload_testflight.sh"
  echo ""
  read -r -p "지금 Xcode 워크스페이스를 열까요? [Y/n]: " OPEN_X
  if [[ "${OPEN_X:-Y}" != "n" && "${OPEN_X:-Y}" != "N" ]]; then
    open "${ROOT}/ios/Runner.xcworkspace"
  fi
else
  echo "✓ 서명 인증서 ${IDENTITIES}개 확인"
  if iljari_ios_has_upload_credentials; then
    echo "✓ 업로드 인증 설정됨 → ./scripts/upload_testflight.sh"
  else
    echo "⚠️  업로드 인증 미완료 — API Key 또는 Apple ID를 fastlane/.env 에 채운 뒤 upload 실행"
  fi
fi

echo ""
