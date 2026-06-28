#!/usr/bin/env bash
# Usage: ./scripts/launch.sh web <site|corporate|admin|seeker> <server|local>
#        ./scripts/launch.sh native <android|ios> <seeker|corporate|admin> <server|local>
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
chmod +x scripts/*.sh 2>/dev/null

KIND="${1:?web|native}"

case "${KIND}" in
  web)
    export ILJARI_ENV="${3:?server|local}"
    exec ./scripts/run_remote_web.sh "${2:?site|corporate|admin|seeker}"
    ;;
  native)
    export ILJARI_ENV="${4:?server|local}"
    exec ./scripts/launch_native.sh "${2:?android|ios}" "${3:?seeker|corporate|admin}" "${ILJARI_ENV}"
    ;;
  *)
    echo "ERROR: ${KIND}"; exit 1
    ;;
esac
