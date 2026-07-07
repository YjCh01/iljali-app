#!/usr/bin/env bash
# Android(Gradle) 빌드용 JDK — 없으면 안내 후 exit 1
iljari_ensure_java() {
  local quiet=0
  if [[ "${1:-}" == "--quiet" ]]; then
    quiet=1
  fi

  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    export PATH="${JAVA_HOME}/bin:${PATH}"
    return 0
  fi

  local candidates=(
    "${HOME}/.iljari/jdk-17/Contents/Home"
    "/Applications/Android Studio.app/Contents/jbr/Contents/Home"
    "/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
    "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
  )

  local home
  for home in "${candidates[@]}"; do
    if [[ -x "${home}/bin/java" ]]; then
      export JAVA_HOME="${home}"
      export PATH="${JAVA_HOME}/bin:${PATH}"
      if [[ "${quiet}" -eq 0 ]]; then
        echo "[Java] JAVA_HOME=${JAVA_HOME}"
      fi
      return 0
    fi
  done

  if command -v /usr/libexec/java_home >/dev/null 2>&1; then
    local detected
    detected="$(/usr/libexec/java_home -v 17 2>/dev/null || /usr/libexec/java_home 2>/dev/null || true)"
    if [[ -n "${detected}" && -x "${detected}/bin/java" ]]; then
      export JAVA_HOME="${detected}"
      export PATH="${JAVA_HOME}/bin:${PATH}"
      if [[ "${quiet}" -eq 0 ]]; then
        echo "[Java] JAVA_HOME=${JAVA_HOME}"
      fi
      return 0
    fi
  fi

  if [[ "${quiet}" -eq 0 ]]; then
    echo ""
    echo "❌ Android 빌드에 Java(JDK)가 필요합니다. 이 Mac에 JDK가 없습니다."
    echo ""
    echo "  → 프로젝트 폴더에서 「도구_Java설치.command」 더블클릭"
    echo ""
    echo "  ※ API·웹 배포는 이미 성공했을 수 있습니다. 앱(AAB/APK)만 이 단계에서 실패한 것입니다."
    echo "  ※ 웹만 다시 올릴 때: ./scripts/deploy_prod_all.sh --web-only"
    echo ""
  fi
  return 1
}
