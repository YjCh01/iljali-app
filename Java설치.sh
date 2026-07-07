#!/usr/bin/env bash
# Android AAB/APK 빌드용 OpenJDK 17 설치 (Homebrew 없어도 됨)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

ZSHRC_MARKER="# iljari-openjdk-17"

pause_close() {
  read -r -p "Enter 키로 창 닫기…" _ || true
}

iljari_write_zshrc_java() {
  local jdk_home="$1"
  local zshrc="${HOME}/.zshrc"

  if [[ -f "${zshrc}" ]] && grep -q "${ZSHRC_MARKER}" "${zshrc}" 2>/dev/null; then
    # 이전에 잘못 들어간 블록 제거 후 다시 씀
    sed -i '' "/${ZSHRC_MARKER}/,+2d" "${zshrc}" 2>/dev/null || true
  fi

  {
    echo ""
    echo "${ZSHRC_MARKER}"
    echo "export JAVA_HOME=\"${jdk_home}\""
    echo "export PATH=\"\${JAVA_HOME}/bin:\${PATH}\""
  } >> "${zshrc}"
}

echo ""
echo "========================================"
echo "  Android 빌드용 Java (JDK 17) 설치"
echo "========================================"
echo ""
echo "Play Store AAB · APK 빌드에 필요합니다."
echo "Homebrew 없어도 자동으로 받아 설치합니다."
echo ""

# shellcheck source=scripts/ensure_java.sh
source scripts/ensure_java.sh
if iljari_ensure_java --quiet; then
  echo "✅ Java가 이미 준비되어 있습니다."
  echo ""
  "${JAVA_HOME}/bin/java" -version 2>&1 || true
  echo ""
  echo "  JAVA_HOME=${JAVA_HOME}"
  echo ""
  echo "  다음: 도구_실서비스한방배포(app포함).command 를 다시 실행하세요."
  echo ""
  pause_close
  exit 0
fi

JDK_HOME=""

# ── 1) Homebrew ──
if command -v brew >/dev/null 2>&1; then
  echo "[1/3] Homebrew로 OpenJDK 17 설치…"
  brew install openjdk@17 2>/dev/null || brew install openjdk@17
  BREW_PREFIX="$(brew --prefix)"
  JDK_HOME="${BREW_PREFIX}/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  if [[ ! -x "${JDK_HOME}/bin/java" ]]; then
    JDK_HOME=""
  fi
fi

# ── 2) Temurin 직접 다운로드 ──
if [[ -z "${JDK_HOME}" || ! -x "${JDK_HOME}/bin/java" ]]; then
  echo "[1/3] JDK 17 직접 다운로드 (Homebrew 불필요)…"
  echo ""
  # shellcheck source=scripts/install_openjdk17_mac.sh
  source scripts/install_openjdk17_mac.sh
  if ! JDK_HOME="$(iljari_install_openjdk17_mac)"; then
    echo ""
    echo "❌ Java 설치에 실패했습니다."
    echo ""
    echo "  대안: Android Studio 설치 (JDK 포함)"
    echo "  https://developer.android.com/studio"
    echo ""
    pause_close
    exit 1
  fi
fi

# 경로 검증 (잘못된 JAVA_HOME이 zshrc에 들어가는 것 방지)
if [[ ! -x "${JDK_HOME}/bin/java" ]]; then
  echo ""
  echo "❌ java 실행 파일을 찾지 못했습니다."
  echo "   JAVA_HOME=${JDK_HOME}"
  echo ""
  pause_close
  exit 1
fi

export JAVA_HOME="${JDK_HOME}"
export PATH="${JAVA_HOME}/bin:${PATH}"

echo ""
echo "[2/3] ~/.zshrc 에 JAVA_HOME 설정…"
iljari_write_zshrc_java "${JDK_HOME}"
echo "      ~/.zshrc 에 저장했습니다."

echo ""
echo "[3/3] 확인…"
"${JAVA_HOME}/bin/java" -version 2>&1
echo ""
echo "  JAVA_HOME=${JAVA_HOME}"
echo "  설치 위치: ${JDK_HOME}"
echo ""

if iljari_ensure_java --quiet; then
  echo "========================================"
  echo "  ✅ Java 설치 완료"
  echo "========================================"
  echo ""
  echo "  다음: 도구_실서비스한방배포(app포함).command 다시 실행"
  echo ""
else
  echo "❌ 설치 후에도 Java를 인식하지 못했습니다."
  echo "   도구_Java설치.command 를 한 번 더 실행해 주세요."
  echo ""
fi

pause_close
