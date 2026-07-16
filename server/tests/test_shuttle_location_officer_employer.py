"""셔틀위치담당자 — 기업 승인요청 → 어드민 승인/반려 (/v1/shuttle/location-officer/*)."""

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app
from app.qc_models import QcMemberRow
from app.database import SessionLocal
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "3033033033"
OTHER_COMPANY_KEY = "4044044044"
ROUTE_ID = "route_employer_self"
DRIVER_EMAIL = "seeker-9201@qc.iljari.co.kr"


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if not db.query(QcMemberRow).filter(QcMemberRow.email == DRIVER_EMAIL).first():
            db.add(
                QcMemberRow(
                    id="qc_employer_self_driver",
                    email=DRIVER_EMAIL,
                    display_name="EMPLOYER SELF DRIVER",
                    member_type="seeker",
                    phone="01099990000",
                )
            )
            db.commit()
    finally:
        db.close()


def _corp_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "employer@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _admin_headers() -> dict[str, str]:
    return {"X-Admin-Api-Key": settings.admin_api_key}


def test_employer_request_does_not_immediately_take_effect():
    res = client.post(
        "/v1/shuttle/location-officer/request",
        headers=_corp_headers(COMPANY_KEY),
        json={
            "seeker_email": DRIVER_EMAIL,
            "route_id": ROUTE_ID,
            "route_name": "본사 셔틀",
        },
    )
    assert res.status_code == 200, res.text
    body = res.json()
    assert body["status"] == "pending"
    assert body["seeker_email"] == DRIVER_EMAIL

    view = client.get(
        "/v1/shuttle/location-officer",
        headers=_corp_headers(COMPANY_KEY),
        params={"route_id": ROUTE_ID},
    )
    assert view.status_code == 200
    # 승인 전이므로 실제 지정은 아직 반영되지 않는다.
    assert view.json().get("seeker_email") != DRIVER_EMAIL


def test_employer_cannot_request_for_a_different_company():
    res = client.post(
        "/v1/shuttle/location-officer/request",
        headers=_corp_headers(OTHER_COMPANY_KEY),
        json={"seeker_email": DRIVER_EMAIL, "route_id": ROUTE_ID},
    )
    # company_key는 토큰에서만 가져오므로, 이 요청은 OTHER_COMPANY_KEY 소속으로
    # 생성될 뿐 COMPANY_KEY 요청 목록을 건드릴 수 없다.
    assert res.status_code == 200
    assert res.json()["company_key"] == OTHER_COMPANY_KEY

    company_requests = client.get(
        "/v1/shuttle/location-officer/requests",
        headers=_corp_headers(COMPANY_KEY),
    )
    assert all(
        item["company_key"] == COMPANY_KEY for item in company_requests.json()["items"]
    )


def test_seeker_token_rejected_from_employer_endpoints():
    seeker_token = issue_token({"sub": DRIVER_EMAIL, "member_type": "seeker"})
    res = client.post(
        "/v1/shuttle/location-officer/request",
        headers={"Authorization": f"Bearer {seeker_token}"},
        json={"seeker_email": DRIVER_EMAIL, "route_id": ROUTE_ID},
    )
    assert res.status_code == 403


def test_admin_approve_makes_request_take_effect():
    route_id = "route_admin_approve"
    created = client.post(
        "/v1/shuttle/location-officer/request",
        headers=_corp_headers(COMPANY_KEY),
        json={
            "seeker_email": DRIVER_EMAIL,
            "route_id": route_id,
            "route_name": "승인 테스트 노선",
        },
    )
    request_id = created.json()["id"]

    pending = client.get("/v1/admin/ops/pilot/officer-requests", headers=_admin_headers())
    assert pending.status_code == 200
    assert any(item["id"] == request_id for item in pending.json()["items"])

    approved = client.post(
        f"/v1/admin/ops/pilot/officer-requests/{request_id}/approve",
        headers=_admin_headers(),
    )
    assert approved.status_code == 200
    assert approved.json()["status"] == "approved"

    view = client.get(
        "/v1/shuttle/location-officer",
        headers=_corp_headers(COMPANY_KEY),
        params={"route_id": route_id},
    )
    assert view.json()["seeker_email"] == DRIVER_EMAIL
    assert view.json()["enabled"] is True

    # 이미 처리된 요청은 다시 승인/반려할 수 없다.
    reapprove = client.post(
        f"/v1/admin/ops/pilot/officer-requests/{request_id}/approve",
        headers=_admin_headers(),
    )
    assert reapprove.status_code == 400


def test_admin_reject_does_not_affect_officer_state():
    route_id = "route_admin_reject"
    created = client.post(
        "/v1/shuttle/location-officer/request",
        headers=_corp_headers(COMPANY_KEY),
        json={
            "seeker_email": DRIVER_EMAIL,
            "route_id": route_id,
        },
    )
    request_id = created.json()["id"]

    rejected = client.post(
        f"/v1/admin/ops/pilot/officer-requests/{request_id}/reject",
        headers=_admin_headers(),
    )
    assert rejected.status_code == 200
    assert rejected.json()["status"] == "rejected"

    view = client.get(
        "/v1/shuttle/location-officer",
        headers=_corp_headers(COMPANY_KEY),
        params={"route_id": route_id},
    )
    assert view.json().get("seeker_email") != DRIVER_EMAIL
