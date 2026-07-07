#!/bin/bash
# 실서비스 웹만 배포 (로그인 UI 등 프론트 변경 반영)
cd "$(dirname "$0")"
exec ./scripts/deploy_prod_all.sh --web-only "$@"
