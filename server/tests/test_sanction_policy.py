from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def test_sanction_policy_catalog():
    r = client.get("/v1/admin/ops/sanction/policy", headers=ADMIN_HEADERS)
    assert r.status_code == 200
    body = r.json()
    assert body["appeal_days"] == 7
    assert "minor_false_ad" in body["employer"]["violations"]
    assert "noshow_1_2" in body["seeker"]["violations"]


def test_apply_seeker_caution_and_lift():
    email = "seeker-sanction-test@qc.iljari.co.kr"

    apply = client.post(
        "/v1/admin/ops/sanction/apply",
        headers=ADMIN_HEADERS,
        json={
            "email": email,
            "member_kind": "seeker",
            "violation_code": "noshow_1_2",
            "reason": "테스트 주의",
        },
    )
    assert apply.status_code == 200
    member = apply.json()["member"]
    assert member["sanction_tier"] == "caution"
    assert member["warning_count"] >= 1
    restrictions = member["restrictions"]
    assert "apply_restriction_until" in restrictions

    status = client.get(
        f"/v1/admin/ops/members/{email}/sanction",
        headers=ADMIN_HEADERS,
    )
    assert status.status_code == 200
    assert len(status.json()["history"]) >= 1

    lift = client.post(
        "/v1/admin/ops/sanction/lift",
        headers=ADMIN_HEADERS,
        json={"email": email, "reason": "테스트 해제", "action": "lift"},
    )
    assert lift.status_code == 200
    assert lift.json()["sanction_tier"] == ""


def test_auto_noshow_hiring_endpoint():
    email = "seeker-noshow-auto@qc.iljari.co.kr"
    r = client.post(
        "/v1/hiring/seeker/no-show/sync",
        json={"seeker_email": email, "streak": 2},
    )
    assert r.status_code == 200
    assert r.json()["applied"] is True
    assert r.json()["sanction"]["member"]["sanction_tier"] == "caution"


def test_company_exposure_limit_on_sync():
    email = "employer-exposure@qc.iljari.co.kr"
    post_id = "exposure_limit_post"
    company_key = "2000000003"

    client.post(
        "/v1/admin/ops/jobs/bulk",
        headers=ADMIN_HEADERS,
        json={
            "posts": [
                {
                    "id": post_id,
                    "title": "노출제한 테스트",
                    "company_key": company_key,
                    "company_name": "감마",
                    "hourly_wage": "10000",
                }
            ]
        },
    )
    client.post(
        "/v1/admin/ops/entitlements/job-pin",
        headers=ADMIN_HEADERS,
        json={"post_id": post_id, "recruitment_pin_active": True},
    )
    client.post(
        "/v1/admin/ops/sanction/apply",
        headers=ADMIN_HEADERS,
        json={
            "email": email,
            "member_kind": "employer",
            "violation_code": "minor_false_ad",
            "company_key": company_key,
        },
    )

    sync = client.get("/v1/sync/bootstrap")
    ent = sync.json()["post_entitlements"].get(post_id, {})
    assert ent.get("exposure_limited") is True
    assert ent.get("recruitment_pin_active") is False


def test_employer_suspension_hides_posts():
    email = "employer-suspend@qc.iljari.co.kr"
    post_id = "sanction_hide_post"

    client.post(
        "/v1/admin/ops/jobs/bulk",
        headers=ADMIN_HEADERS,
        json={
            "posts": [
                {
                    "id": post_id,
                    "title": "제재 숨김 테스트",
                    "company_key": "2000000002",
                    "company_name": "베타",
                    "hourly_wage": "10000",
                }
            ]
        },
    )

    apply = client.post(
        "/v1/admin/ops/sanction/apply",
        headers=ADMIN_HEADERS,
        json={
            "email": email,
            "member_kind": "employer",
            "violation_code": "wage_theft",
            "reason": "임금 체불 테스트",
            "company_key": "2000000002",
            "days": 30,
        },
    )
    assert apply.status_code == 200
    assert apply.json()["member"]["is_suspended"] is True

    sync = client.get("/v1/sync/bootstrap")
    posts = {p["id"]: p for p in sync.json()["posts"]}
    assert posts[post_id]["status"] == "hidden"
