#!/bin/bash
# 실서비스 한방 배포 — API + 웹(site·admin) + 앱 빌드(·스토어)
cd "$(dirname "$0")"
exec ./scripts/deploy_prod_all.sh "$@"
