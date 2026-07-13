#!/usr/bin/env bash
# iOS / TestFlight — fastlane env, Xcode team, 서명·업로드 준비 상태
# shellcheck disable=SC2034
set -euo pipefail

iljari_ios_root() {
  if [[ -n "${ILJARI_ROOT:-}" ]]; then
    echo "${ILJARI_ROOT}"
  else
    echo "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  fi
}

iljari_ios_env_file() {
  echo "$(iljari_ios_root)/fastlane/.env"
}

# Xcode project DEVELOPMENT_TEAM (첫 값) — rg 없어도 grep/sed 로 동작
iljari_ios_team_from_xcode() {
  local root pbxproj team
  root="$(iljari_ios_root)"
  pbxproj="${root}/ios/Runner.xcodeproj/project.pbxproj"
  [[ -f "${pbxproj}" ]] || return 1

  if command -v rg >/dev/null 2>&1; then
    team="$(rg 'DEVELOPMENT_TEAM = ([A-Z0-9]{10});' "${pbxproj}" -o -r '$1' 2>/dev/null | head -1 || true)"
  else
    team="$(grep -m1 'DEVELOPMENT_TEAM = ' "${pbxproj}" 2>/dev/null \
      | sed -n 's/.*DEVELOPMENT_TEAM = \([A-Z0-9]\{10\}\);.*/\1/p' || true)"
  fi
  [[ -n "${team}" ]] || return 1
  echo "${team}"
}

iljari_ios_load_env() {
  local env_file
  env_file="$(iljari_ios_env_file)"
  APPLE_TEAM_ID=""
  ASC_KEY_ID=""
  ASC_ISSUER_ID=""
  ASC_KEY_PATH=""
  FASTLANE_USER=""
  FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=""

  if [[ -f "${env_file}" ]]; then
    # shellcheck disable=SC1090
    set -a
    source "${env_file}" 2>/dev/null || true
    set +a
  fi

  if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    APPLE_TEAM_ID="$(iljari_ios_team_from_xcode || true)"
  fi
  export APPLE_TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH FASTLANE_USER
  export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
}

iljari_ios_has_upload_credentials() {
  iljari_ios_load_env
  if [[ -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_PATH:-}" && -f "${ASC_KEY_PATH}" ]]; then
    return 0
  fi
  if [[ -n "${FASTLANE_USER:-}" && -n "${FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD:-}" ]]; then
    return 0
  fi
  return 1
}

iljari_ios_signing_identity_count() {
  local out count
  out="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  if command -v rg >/dev/null 2>&1; then
    count="$(printf '%s\n' "${out}" | rg -c 'Apple Development|Apple Distribution|iPhone Distribution' || true)"
  else
    count="$(printf '%s\n' "${out}" | grep -cE 'Apple Development|Apple Distribution|iPhone Distribution' || true)"
  fi
  echo "${count:-0}"
}

iljari_ios_preflight() {
  local root env_file team xcode_team ids upload_ok
  root="$(iljari_ios_root)"
  env_file="$(iljari_ios_env_file)"
  iljari_ios_load_env
  team="${APPLE_TEAM_ID:-}"
  xcode_team="$(iljari_ios_team_from_xcode || true)"
  ids="$(iljari_ios_signing_identity_count)"
  ids="${ids:-0}"
  upload_ok=0
  iljari_ios_has_upload_credentials && upload_ok=1

  echo ""
  echo "── iOS / TestFlight preflight ──"
  if [[ -f "${env_file}" ]]; then
    echo "  fastlane/.env : 있음"
  else
    echo "  fastlane/.env : 없음 → ./scripts/setup_testflight.sh"
  fi
  echo "  Team ID       : ${team:-(미설정)}${xcode_team:+ (Xcode: ${xcode_team})}"
  echo "  서명 인증서   : ${ids}개"
  if [[ "${upload_ok}" == 1 ]]; then
    if [[ -n "${ASC_KEY_ID:-}" && -f "${ASC_KEY_PATH:-/dev/null}" ]]; then
      echo "  업로드 인증   : App Store Connect API Key ✓"
    else
      echo "  업로드 인증   : Apple ID + 앱 전용 비밀번호 ✓"
    fi
  else
    echo "  업로드 인증   : ✗ (API Key 또는 Apple ID 필요)"
    echo "                  → ./scripts/setup_testflight.sh"
  fi
  if [[ "${ids}" == 0 ]]; then
    echo "  ⚠️  키체인에 서명 인증서 없음 — Xcode → Signing & Capabilities"
  fi
  if [[ -z "${team}" ]]; then
    echo "  ⚠️  Team ID 없음 — Xcode에서 Team 선택 후 재시도"
    return 1
  fi
  if [[ "${upload_ok}" == 0 ]]; then
    return 2
  fi
  return 0
}

iljari_ios_upload_skip_reason() {
  local env_file root
  root="$(iljari_ios_root)"
  env_file="$(iljari_ios_env_file)"
  iljari_ios_load_env

  if [[ ! -f "${env_file}" ]]; then
    echo "TestFlight 업로드 설정 없음 — 도구_TestFlight설정.command (1회)"
    return 0
  fi

  if [[ -z "${APPLE_TEAM_ID:-}" ]]; then
    echo "Team ID 미설정 — Xcode Runner 서명 탭에서 Team 선택 또는 setup_testflight.sh"
    return 0
  fi

  if ! iljari_ios_has_upload_credentials; then
    echo "fastlane/.env 에 App Store Connect API Key 또는 Apple ID+앱전용비밀번호 필요 — setup_testflight.sh"
    return 0
  fi

  if [[ "$(iljari_ios_signing_identity_count)" == 0 ]]; then
    echo "Mac 키체인에 iOS 서명 인증서 없음 — Xcode Accounts·Signing 설정"
    return 0
  fi

  echo ""
}
