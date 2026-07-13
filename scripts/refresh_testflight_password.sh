#!/usr/bin/env bash
# TestFlight — Apple 앱 전용 비밀번호만 쉽게 갱신 (+ 선택 업로드)
# 로그인 비밀번호가 아닙니다. appleid.apple.com 에서 만드는 xxxx-xxxx-xxxx-xxxx 형식입니다.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "${ROOT}"
export ILJARI_ROOT="${ROOT}"

# shellcheck source=scripts/iljari_ios_env.sh
source scripts/iljari_ios_env.sh

ENV_FILE="$(iljari_ios_env_file)"
EXAMPLE="${ROOT}/fastlane/.env.example"

# 앱 전용 비밀번호 형식: abcd-efgh-ijkl-mnop (하이픈 3개, @ 없음)
_is_app_specific_password() {
  local v="$1"
  [[ "${v}" =~ ^[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}$ ]]
}

_is_email() {
  local v="$1"
  [[ "${v}" == *"@"*"."* ]]
}

clear 2>/dev/null || true
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  TestFlight 비밀번호 갱신 (쉬운 안내)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "이 도구가 하는 일:"
echo "  1) 브라우저에서 Apple ID 사이트 열기"
echo "  2) 앱 전용 비밀번호 만들기 안내"
echo "  3) 그 값을 fastlane/.env 에 저장"
echo "  4) (선택) 이미 만든 map.ipa 를 TestFlight 에 업로드"
echo ""
echo "※ Apple 로그인 비밀번호 ❌"
echo "※ 앱 전용 비밀번호 (xxxx-xxxx-xxxx-xxxx) ✅"
echo ""
read -r -p "계속하려면 Enter…" _

if [[ ! -f "${ENV_FILE}" ]]; then
  cp "${EXAMPLE}" "${ENV_FILE}"
  echo ""
  echo "fastlane/.env 를 새로 만들었습니다."
fi

iljari_ios_load_env

if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  APPLE_TEAM_ID="$(iljari_ios_team_from_xcode || true)"
fi
if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
  APPLE_TEAM_ID="JR36AGC7R9"
fi

# 이전에 이메일/비밀번호를 바꿔 넣은 경우 자동 복구
if _is_app_specific_password "${FASTLANE_USER:-}"; then
  echo ""
  echo "⚠️  이전에 앱 전용 비밀번호가「이메일」칸에 들어가 있었습니다."
  echo "   지금 자동으로 고칩니다 (이메일 = ashronze@gmail.com)."
  echo ""
  FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="${FASTLANE_USER}"
  FASTLANE_USER="ashronze@gmail.com"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1단계 — 앱 전용 비밀번호 만들기"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  ① Apple ID로 로그인 (ashronze@gmail.com)"
echo "  ② 「로그인 및 보안」"
echo "  ③ 「앱 전용 비밀번호」 → 생성"
echo "  ④ xxxx-xxxx-xxxx-xxxx 복사 (한 번만 보임)"
echo ""
echo "주소: https://appleid.apple.com/account/manage"
echo ""
read -r -p "브라우저를 열까요? [Y/n]: " OPEN_B
if [[ "${OPEN_B:-Y}" != "n" && "${OPEN_B:-Y}" != "N" ]]; then
  open "https://appleid.apple.com/account/manage" 2>/dev/null || true
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  2단계 — 붙여넣기 (순서 주의!)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "【먼저】앱에서 복사한 비밀번호만 붙여넣기"
echo "      형식: xxxx-xxxx-xxxx-xxxx"
echo "      (화면에 안 보입니다)"
echo ""
read -r -s -p "① 앱 전용 비밀번호: " PASS_IN
echo ""
PASS_IN="$(printf '%s' "${PASS_IN}" | tr -d '[:space:]')"

if [[ -z "${PASS_IN}" ]]; then
  echo ""
  echo "❌ 비밀번호가 비어 있습니다."
  exit 1
fi

# 이메일을 비밀번호 칸에 넣은 경우
if _is_email "${PASS_IN}"; then
  echo ""
  echo "❌ 여기에는 이메일이 아니라 앱 전용 비밀번호를 넣어야 합니다."
  echo "   (지금 이메일을 붙여넣으신 것 같습니다)"
  exit 1
fi

if ! _is_app_specific_password "${PASS_IN}"; then
  echo ""
  echo "⚠️  형식이 xxxx-xxxx-xxxx-xxxx 가 아닙니다."
  echo "   Apple 로그인 비밀번호가 아닌지 확인하세요."
  read -r -p "그래도 저장할까요? [y/N]: " FORCE
  if [[ "${FORCE:-}" != "y" && "${FORCE:-}" != "Y" ]]; then
    echo "취소. appleid.apple.com 에서 앱 전용 비밀번호를 다시 만드세요."
    exit 1
  fi
fi

echo ""
echo "【다음】Apple ID 이메일 (계정 주소)"
echo "      기본값이면 그냥 Enter 만 누르세요."
echo ""
DEFAULT_USER="ashronze@gmail.com"
# 깨진 값이 이메일 형식이 아니면 기본값 사용
if _is_email "${FASTLANE_USER:-}"; then
  DEFAULT_USER="${FASTLANE_USER}"
fi
read -r -p "② Apple ID 이메일 [${DEFAULT_USER}]: " USER_IN
USER_IN="${USER_IN:-${DEFAULT_USER}}"
USER_IN="$(printf '%s' "${USER_IN}" | tr -d '[:space:]')"

# 비밀번호를 이메일 칸에 넣은 경우 → 자동 교정
if _is_app_specific_password "${USER_IN}"; then
  echo ""
  echo "⚠️  이메일 칸에 비밀번호를 넣으셨습니다. 자동으로 바꿉니다."
  PASS_IN="${USER_IN}"
  USER_IN="${DEFAULT_USER}"
  if ! _is_email "${USER_IN}"; then
    USER_IN="ashronze@gmail.com"
  fi
  echo "   → 이메일: ${USER_IN}"
  echo "   → 비밀번호: (방금 붙여넣은 값으로 저장)"
fi

if ! _is_email "${USER_IN}"; then
  echo ""
  echo "❌ 이메일이 아닙니다: ${USER_IN}"
  echo "   예: ashronze@gmail.com"
  echo "   (앱 전용 비밀번호 xxxx-xxxx-… 를 여기에 넣지 마세요)"
  exit 1
fi

_tmp="$(mktemp)"
{
  if [[ -f "${ENV_FILE}" ]]; then
    # shellcheck disable=SC1090
    set -a
    # shellcheck disable=SC1091
    source "${ENV_FILE}" 2>/dev/null || true
    set +a
  fi
  cat <<EOF
APPLE_TEAM_ID=${APPLE_TEAM_ID:-}
ASC_KEY_ID=${ASC_KEY_ID:-}
ASC_ISSUER_ID=${ASC_ISSUER_ID:-}
ASC_KEY_PATH=${ASC_KEY_PATH:-}
FASTLANE_USER=${USER_IN}
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=${PASS_IN}
EOF
} > "${_tmp}"
mv "${_tmp}" "${ENV_FILE}"
chmod 600 "${ENV_FILE}" 2>/dev/null || true

echo ""
echo "✅ 저장 완료 → fastlane/.env"
echo "   Apple ID (이메일): ${USER_IN}"
echo "   Team ID         : ${APPLE_TEAM_ID}"
echo "   비밀번호        : ****-****-****-**** (저장됨)"
echo ""

IPA="$(ls -t build/ios/ipa/*.ipa 2>/dev/null | head -1 || true)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  3단계 — TestFlight 업로드 (선택)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
if [[ -n "${IPA}" ]]; then
  echo "준비된 IPA: ${IPA}"
else
  echo "⚠️  IPA 없음 (build/ios/ipa/*.ipa)"
fi
echo ""
echo "  [1] 기존 IPA만 업로드 (빠름)"
echo "  [2] IPA 다시 빌드 + 업로드"
echo "  [3] Transporter로 업로드"
echo "  [4] 지금은 저장만"
echo ""
read -r -p "선택 [1/2/3/4] (기본 1): " CHOICE
CHOICE="${CHOICE:-1}"

case "${CHOICE}" in
  1)
    if [[ -z "${IPA}" ]]; then
      echo "❌ IPA 없음 — [2] 선택"
      exit 1
    fi
    exec ./scripts/upload_testflight.sh --upload-only
    ;;
  2)
    exec ./scripts/upload_testflight.sh
    ;;
  3)
    if [[ -z "${IPA}" ]]; then
      echo "❌ IPA 없음 — [2] 선택"
      exit 1
    fi
    exec ./scripts/upload_transporter.sh
    ;;
  4|*)
    echo ""
    echo "저장만 했습니다. 업로드: 도구_TestFlight업로드만.command"
    echo ""
    ;;
esac
