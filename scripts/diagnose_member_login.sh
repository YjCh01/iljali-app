#!/usr/bin/env bash
# 회원 로그인 진단 — 서버 qc_members 조회 (어드민 API)
# Usage: ./scripts/diagnose_member_login.sh ashronze@gmail.com
set -euo pipefail

cd "$(dirname "$0")/.."
# shellcheck source=scripts/api_target.sh
source scripts/api_target.sh

EMAIL="${1:-}"
if [[ -z "${EMAIL}" ]]; then
  echo "Usage: $0 <email>" >&2
  exit 1
fi

API="$(iljari_resolve_compliance_api_url)"
KEY="$(iljari_resolve_admin_api_key)"
ENC="$(python3 -c "import urllib.parse; print(urllib.parse.quote('${EMAIL}'))")"

echo "=== 회원 조회: ${EMAIL} ==="
echo "API: ${API}"
echo ""

export DIAG_MEMBER_JSON
DIAG_MEMBER_JSON="$(curl -sk -H "X-Admin-Api-Key: ${KEY}" \
  "${API}/v1/admin/ops/members?q=${ENC}&limit=10")"

python3 <<'PY'
import json, os, sys

data = json.loads(os.environ["DIAG_MEMBER_JSON"])
members = data.get("members") or []
if not members:
    print("❌ 서버에 해당 이메일 회원 없음")
    print("   → 개인회원 가입을 다시 하거나, 기업회원 로그인인지 확인")
    sys.exit(1)

for m in members:
    print(f"✓ email: {m.get('email')}")
    print(f"  이름: {m.get('display_name')}")
    print(f"  유형: {m.get('member_type')}  (seeker=개인, corporate=기업)")
    print(f"  전화: {m.get('phone') or '-'}")
    has_pw = m.get("has_password")
    print(
        f"  비밀번호 설정: {'예' if has_pw else '아니오 (QC 레거시 QcTest1234! 만 가능)'}"
    )
    print(
        f"  정지: suspended={m.get('is_suspended')} "
        f"banned={m.get('is_permanently_banned')}"
    )
    print(f"  가입: {m.get('created_at')}")
    mt = m.get("member_type")
    if mt in ("corporate", "employer"):
        print("  ⚠️  기업회원 — 개인 로그인 말고 기업회원 로그인 사용")
    elif mt == "seeker" and not has_pw:
        print("  ⚠️  비밀번호 미설정 — QcTest1234! 또는 비밀번호 찾기 필요")
PY
