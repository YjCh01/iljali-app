#!/bin/bash
# 통합 iljari.app 배포 — 게이트웨이에서 「기업회원」 선택
cd "$(dirname "$0")"
exec ./scripts/launch.sh web site server
