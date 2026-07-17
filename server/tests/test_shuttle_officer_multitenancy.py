"""버스위치 공유 담당 — 회사·노선별 독립 슬롯(멀티테넌트) 검증."""

from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.main import app
from app.qc_models import QcMemberRow

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}

COMPANY_A = "1111111111"
COMPANY_B = "2222222222"
ROUTE_A = "route_a"
ROUTE_B = "route_b"
DRIVER_A = "seeker-9101@qc.iljari.co.kr"
DRIVER_B = "seeker-9102@qc.iljari.co.kr"
TODAY = datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        for email, member_id, name, phone in [
            (DRIVER_A, "qc_mt_driver_a", "MT DRIVER A", "01055556666"),
            (DRIVER_B, "qc_mt_driver_b", "MT DRIVER B", "01077778888"),
        ]:
            row = db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
            if row is None:
                db.add(
                    QcMemberRow(
                        id=member_id,
                        email=email,
                        display_name=name,
                        member_type="seeker",
                        phone=phone,
                    )
                )
        db.commit()
    finally:
        db.close()


def _designate(*, company_key: str, route_id: str, seeker_email: str) -> None:
    res = client.put(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        json={
            "seeker_email": seeker_email,
            "enabled": True,
            "company_key": company_key,
            "company_name": f"company-{company_key}",
            "route_id": route_id,
            "route_name": f"route-{route_id}",
        },
    )
    assert res.status_code == 200, res.text


def _view(*, company_key: str, route_id: str) -> dict:
    res = client.get(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        params={"company_key": company_key, "route_id": route_id},
    )
    assert res.status_code == 200, res.text
    return res.json()


def test_two_companies_have_independent_concurrent_officers():
    _designate(company_key=COMPANY_A, route_id=ROUTE_A, seeker_email=DRIVER_A)
    _designate(company_key=COMPANY_B, route_id=ROUTE_B, seeker_email=DRIVER_B)

    view_a = _view(company_key=COMPANY_A, route_id=ROUTE_A)
    view_b = _view(company_key=COMPANY_B, route_id=ROUTE_B)

    assert view_a["seeker_email"] == DRIVER_A
    assert view_a["enabled"] is True
    assert view_b["seeker_email"] == DRIVER_B
    assert view_b["enabled"] is True
    # 서로 다른 program_key — 슬롯이 독립적으로 저장됨을 확인
    assert view_a["program_key"] != view_b["program_key"]


def test_disabling_company_a_officer_does_not_affect_company_b():
    client.put(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        json={
            "seeker_email": DRIVER_A,
            "enabled": False,
            "company_key": COMPANY_A,
            "route_id": ROUTE_A,
        },
    )
    view_a = _view(company_key=COMPANY_A, route_id=ROUTE_A)
    view_b = _view(company_key=COMPANY_B, route_id=ROUTE_B)
    assert view_a["enabled"] is False
    assert view_b["enabled"] is True
    assert view_b["seeker_email"] == DRIVER_B


def test_driver_a_status_reflects_their_own_company_only():
    login_a = client.post(
        "/v1/auth/login",
        json={"email": DRIVER_A, "password": "QcTest1234!"},
    )
    assert login_a.status_code == 200, login_a.text
    token_a = login_a.json()["access_token"]

    # A는 회사A에서 비활성화됐으므로 담당자가 아니어야 함
    status_a = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert status_a.status_code == 200
    assert status_a.json()["is_designated"] is False

    login_b = client.post(
        "/v1/auth/login",
        json={"email": DRIVER_B, "password": "QcTest1234!"},
    )
    assert login_b.status_code == 200, login_b.text
    token_b = login_b.json()["access_token"]

    status_b = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert status_b.status_code == 200
    body_b = status_b.json()
    assert body_b["is_designated"] is True
    assert body_b["company_key"] == COMPANY_B
    assert body_b["route_id"] == ROUTE_B
