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


def test_admin_ops_health():
    r = client.get("/v1/admin/ops/health", headers=ADMIN_HEADERS)
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


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
