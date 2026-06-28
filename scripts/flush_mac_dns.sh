#!/usr/bin/env bash
# 맥 DNS 캐시만 (맥 로그인 비번)
cd "$(dirname "$0")/.."
clear
echo "맥 로그인 비밀번호 입력 (NCP 비번 아님)"
sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
echo "✅ 완료 → 도구_브라우저열기.command"
read -r -p "Enter…" _
