#!/bin/bash
# 더블클릭 → Android 빌드용 JDK 17 설치 (Homebrew)
cd "$(dirname "$0")"
chmod +x Java설치.sh scripts/ensure_java.sh 2>/dev/null
exec ./Java설치.sh
