from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def _corp_auth_headers(company_key: str = "1234567890") -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_workplace_mismatch_report_list_and_approve():
    headers = _corp_auth_headers()
    created = client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "id": "mismatch_post_1",
            "title": "다른 근무지 공고",
            "company_name": "테스트물류",
            "company_key": "1234567890",
            "warehouse_name": "경기 안성 물류센터",
            "status": "closed",
        },
    )
    assert created.status_code == 200, created.text

    report = client.post(
        "/v1/compliance/workplace-mismatch",
        headers=headers,
        json={
            "company_key": "1234567890",
            "company_name": "테스트물류",
            "head_office_address": "서울 강남구",
            "workplace_address": "경기 안성시",
            "post_id": "mismatch_post_1",
            "post_title": "다른 근무지 공고",
            "distance_meters": 45000,
            "reason": "실근무지와 사업자 소재지 불일치",
        },
    )
    assert report.status_code == 200, report.text
    flag_id = report.json()["flag"]["id"]

    duplicate = client.post(
        "/v1/compliance/workplace-mismatch",
        headers=headers,
        json={
            "company_key": "1234567890",
            "post_id": "mismatch_post_1",
        },
    )
    assert duplicate.status_code == 200
    assert duplicate.json()["flag"]["id"] == flag_id

    pending = client.get(
        "/v1/admin/ops/compliance/workplace-mismatch/pending",
        headers=ADMIN_HEADERS,
    )
    assert pending.status_code == 200, pending.text
    body = pending.json()
    assert body["count"] >= 1
    assert any(f["id"] == flag_id for f in body["flags"])

    approved = client.post(
        f"/v1/admin/ops/compliance/workplace-mismatch/{flag_id}/approve-stated-workplace",
        headers=ADMIN_HEADERS,
    )
    assert approved.status_code == 200, approved.text
    assert approved.json()["post_status"] == "recruiting"

    post = client.get("/v1/job-board/posts/mismatch_post_1")
    assert post.status_code == 200
    assert post.json()["status"] == "recruiting"

    pending_after = client.get(
        "/v1/admin/ops/compliance/workplace-mismatch/pending",
        headers=ADMIN_HEADERS,
    )
    assert pending_after.status_code == 200
    assert all(f["id"] != flag_id for f in pending_after.json()["flags"])


def test_workplace_mismatch_rejects_other_company():
    owner = _corp_auth_headers("1234567890")
    other = _corp_auth_headers("9876543210")
    denied = client.post(
        "/v1/compliance/workplace-mismatch",
        headers=other,
        json={
            "company_key": "1234567890",
            "post_id": "mismatch_post_1",
        },
    )
    assert denied.status_code == 403

    # sanity — owner can still report for own company if not duplicate
    ok = client.post(
        "/v1/compliance/workplace-mismatch",
        headers=owner,
        json={
            "company_key": "1234567890",
            "post_id": "mismatch_post_2",
            "post_title": "두번째",
        },
    )
    assert ok.status_code == 200, ok.text
