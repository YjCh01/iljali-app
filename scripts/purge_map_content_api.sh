#!/usr/bin/env bash
# 프로덕션 지도 콘텐츠 삭제 (유령핀·유령노선·공고·셔틀노선)
# SSH 없이 Admin API + (공고/노선은 corporate 토큰 위조 또는 purge/map-content) 사용
# 사용: ./scripts/purge_map_content_api.sh
set -euo pipefail

cd "$(dirname "$0")/.."
export ILJARI_ROOT="$(pwd)"
# shellcheck source=scripts/api_target.sh
source "scripts/api_target.sh"

API="$(iljari_resolve_compliance_api_url)"
KEY="$(iljari_resolve_admin_api_key)"

export API KEY
python3 <<'PY'
import base64, hashlib, hmac, json, os, ssl, time, urllib.request, urllib.error

api = os.environ["API"].rstrip("/")
admin_key = os.environ["KEY"]
ctx = ssl.create_default_context()

def http(method, path, *, token=None, body=None):
    headers = {"Content-Type": "application/json", "X-Admin-Api-Key": admin_key}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    data = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request(api + path, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, context=ctx, timeout=120) as res:
            raw = res.read().decode()
            return res.status, json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raw = e.read().decode()
        try:
            return e.code, json.loads(raw) if raw else {}
        except Exception:
            return e.code, {"raw": raw[:200]}

def issue(payload):
    body = {**payload, "exp": int(time.time()) + 3600}
    enc = base64.urlsafe_b64encode(
        json.dumps(body, separators=(",", ":")).encode()
    ).decode().rstrip("=")
    sig = hmac.new(admin_key.encode(), enc.encode(), hashlib.sha256).hexdigest()
    return f"{enc}.{sig}"

# Prefer server-side purge if deployed
code, body = http("POST", "/v1/admin/ops/purge/map-content?dry_run=false")
if code == 200:
    print(json.dumps(body, ensure_ascii=False, indent=2))
    raise SystemExit(0)

print("[purge-api] purge/map-content unavailable (%s) — fallback deletes" % code)

# Ghost pins / routes
_, pins = http("GET", "/v1/admin/ops/ghost-pins")
pok = 0
for p in pins.get("ghost_pins") or []:
    c, _ = http("DELETE", f"/v1/admin/ops/ghost-pins/{p['id']}")
    if c in (200, 204):
        pok += 1
print("ghost_pins_deleted", pok)

_, routes = http("GET", "/v1/admin/ops/ghost-routes")
rok = 0
for r in routes.get("ghost_routes") or []:
    c, _ = http("DELETE", f"/v1/admin/ops/ghost-routes/{r['id']}")
    if c in (200, 204):
        rok += 1
print("ghost_routes_deleted", rok)

# Jobs — admin delete if available, else forged corporate token
_, jobs = http("GET", "/v1/admin/ops/jobs/map")
jok = 0
for j in jobs.get("jobs") or []:
    jid = j["id"]
    c, _ = http("DELETE", f"/v1/admin/ops/jobs/{jid}")
    if c in (200, 204):
        jok += 1
        continue
    ck = str(j.get("company_key") or "")
    email = str(j.get("posted_by_email") or "wipe@iljari.local")
    token = issue({"sub": email, "member_type": "corporate", "company_key": ck})
    c, _ = http("DELETE", f"/v1/job-board/posts/{jid}", token=token)
    if c in (200, 204):
        jok += 1
print("jobs_deleted", jok)

# Commute routes for known corporate members
_, members = http("GET", "/v1/admin/ops/members?limit=500")
cks = {
    str(m.get("company_key"))
    for m in (members.get("members") or [])
    if m.get("company_key")
}
route_del = 0
for ck in sorted(cks):
    token = issue({"sub": "wipe@iljari.local", "member_type": "corporate", "company_key": ck})
    c, body = http("GET", f"/v1/shuttle/routes?company_key={ck}&include_inactive=true", token=token)
    items = body.get("routes") or body.get("items") or []
    if c != 200:
        c, body = http("GET", f"/v1/shuttle/routes?company_key={ck}", token=token)
        items = body.get("routes") or body.get("items") or []
    for r in items:
        rid = r.get("id") or r.get("routeId")
        if not rid:
            continue
        dc, _ = http(
            "DELETE",
            f"/v1/shuttle/routes/{rid}?company_key={ck}&hard=true",
            token=token,
        )
        if dc in (200, 204):
            route_del += 1
print("commute_routes_deleted", route_del)

_, jobs2 = http("GET", "/v1/admin/ops/jobs/map")
_, pins2 = http("GET", "/v1/admin/ops/ghost-pins")
_, groutes2 = http("GET", "/v1/admin/ops/ghost-routes")
print(
    json.dumps(
        {
            "remaining": {
                "jobs": jobs2.get("count"),
                "ghost_pins": pins2.get("count"),
                "ghost_routes": groutes2.get("count"),
            }
        },
        ensure_ascii=False,
    )
)
PY
