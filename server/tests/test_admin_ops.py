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


def test_admin_ops_stats():
    r = client.get("/v1/admin/ops/stats", headers=ADMIN_HEADERS)
    assert r.status_code == 200, r.text
    body = r.json()
    assert "seekers" in body
    assert "job_posts" in body


def test_seed_seekers_and_sanction():
    r = client.post(
        "/v1/admin/ops/seed/seekers",
        headers=ADMIN_HEADERS,
        json={"count": 5, "start_index": 1},
    )
    assert r.status_code == 200
    assert r.json()["created"] == 5

    ban = client.post(
        "/v1/admin/ops/members/sanction",
        headers=ADMIN_HEADERS,
        json={
            "email": "seeker-0003@qc.iljari.co.kr",
            "action": "permanent_ban",
            "reason": "QC test ban",
        },
    )
    assert ban.status_code == 200
    assert ban.json()["is_permanently_banned"] is True


def test_bulk_jobs_and_sync_bootstrap():
    r = client.post(
        "/v1/admin/ops/jobs/bulk",
        headers=ADMIN_HEADERS,
        json={
            "posts": [
                {
                    "id": "qc_test_post",
                    "title": "QC 테스트 공고",
                    "company_key": "1000000001",
                    "company_name": "알파",
                    "hourly_wage": "11000",
                }
            ]
        },
    )
    assert r.status_code == 200
    assert r.json()["imported"] == 1

    pin = client.post(
        "/v1/admin/ops/entitlements/job-pin",
        headers=ADMIN_HEADERS,
        json={"post_id": "qc_test_post", "recruitment_pin_active": True},
    )
    assert pin.status_code == 200

    sync = client.get("/v1/sync/bootstrap")
    assert sync.status_code == 200
    body = sync.json()
    assert body["counts"]["posts"] >= 1
    assert "qc_test_post" in body["post_entitlements"]


def test_corporate_signup_verification_admin_approve():
    signup = client.post(
        "/v1/auth/signup/corporate",
        json={
            "email": "corp-verify@test.co.kr",
            "password": "TestPass1!",
            "display_name": "라인헬스케어 담당",
            "company_key": "1234567890",
            "company_name": "라인헬스케어",
            "phone": "01012345678",
            "contact_person_name": "담당자",
            "handler_code": "main",
            "org_role": "recruiter",
        },
    )
    assert signup.status_code == 200, signup.text

    verify = client.get(
        "/v1/admin/ops/companies/1234567890/verification",
        headers=ADMIN_HEADERS,
    )
    assert verify.status_code == 200, verify.text
    body = verify.json()
    assert body["needs_admin_approval"] is True
    assert body["has_registered_member"] is True
    assert body["has_server_record"] is False

    approve = client.post(
        "/v1/admin/ops/companies/1234567890/approve-verification",
        headers=ADMIN_HEADERS,
        json={},
    )
    assert approve.status_code == 200, approve.text
    assert approve.json()["verification_status"] == "verified"

    after = client.get(
        "/v1/admin/ops/companies/1234567890/verification",
        headers=ADMIN_HEADERS,
    )
    assert after.json()["needs_admin_approval"] is False
    assert after.json()["has_server_record"] is True
