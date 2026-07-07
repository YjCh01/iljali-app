"""통근 셔틀 E2E — 노선 저장 → 합격자 조회 → 동의 → 정류장 선택."""

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.database import SessionLocal
from app.job_sync_models import JobApplicationRow
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "1122334455"
ROUTE_ID = "route_e2e_1"
APP_ID = "app_shuttle_e2e"
SEEKER = "shuttle.e2e@example.com"


def _corp_headers() -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-e2e@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": COMPANY_KEY,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _seeker_headers() -> dict[str, str]:
    token = issue_token({"sub": SEEKER, "member_type": "seeker"})
    return {"Authorization": f"Bearer {token}"}


def _seed_scheduled_application():
    db = SessionLocal()
    try:
        row = db.get(JobApplicationRow, APP_ID)
        if row is None:
            db.add(
                JobApplicationRow(
                    id=APP_ID,
                    post_id="post_e2e",
                    post_title="E2E 물류",
                    company_name="E2E 물류",
                    company_key=COMPANY_KEY,
                    seeker_email=SEEKER,
                    seeker_name="테스트",
                    status="scheduled",
                    applied_at=datetime.now(timezone.utc),
                )
            )
            db.commit()
        else:
            row.status = "scheduled"
            row.company_key = COMPANY_KEY
            db.commit()
    finally:
        db.close()


def test_shuttle_e2e_route_share_and_preference():
    corp = _corp_headers()
    seeker = _seeker_headers()
    _seed_scheduled_application()

    route = {
        "id": ROUTE_ID,
        "companyKey": COMPANY_KEY,
        "routeName": "E2E 1호차",
        "active": True,
        "overlayColorHex": "#E53935",
        "stops": [
            {
                "id": "stop_a",
                "label": "첫 정류장",
                "coordinate": {"latitude": 37.5, "longitude": 127.0},
                "departureTime": "07:00",
            },
            {
                "id": "__shuttle_workplace__",
                "label": "근무지",
                "coordinate": {"latitude": 37.51, "longitude": 127.01},
                "arrivalTime": "08:30",
            },
        ],
        "polylinePoints": [],
    }
    upsert = client.put(f"/v1/shuttle/routes/{ROUTE_ID}", headers=corp, json=route)
    assert upsert.status_code == 200, upsert.text

    # 합격자는 scheduled 상태라 노선 조회 가능
    listed = client.get(
        "/v1/shuttle/routes",
        headers=seeker,
        params={"company_key": COMPANY_KEY},
    )
    assert listed.status_code == 200, listed.text
    assert any(item["id"] == ROUTE_ID for item in listed.json()["items"])

    offer = client.post(
        "/v1/shuttle/route-share/offer",
        headers=corp,
        json={
            "application_id": APP_ID,
            "company_key": COMPANY_KEY,
            "company_name": "E2E 물류",
            "route_count": 1,
        },
    )
    assert offer.status_code == 200, offer.text

    consent = client.put(
        "/v1/shuttle/route-share/consent",
        headers=seeker,
        json={
            "company_key": COMPANY_KEY,
            "opted_in": True,
            "tower_participation_consented": True,
        },
    )
    assert consent.status_code == 200, consent.text
    assert consent.json()["opted_in"] is True

    pref = client.put(
        "/v1/shuttle/preferences",
        headers=seeker,
        json={
            "company_key": COMPANY_KEY,
            "company_name": "E2E 물류",
            "route_id": ROUTE_ID,
            "route_name": "E2E 1호차",
            "stop_id": "stop_a",
            "stop_label": "첫 정류장",
            "pickup_time": "07:00",
        },
    )
    assert pref.status_code == 200, pref.text
    assert pref.json()["route_id"] == ROUTE_ID

    prefs = client.get("/v1/shuttle/preferences/me", headers=seeker)
    assert prefs.status_code == 200
    assert any(p["route_id"] == ROUTE_ID for p in prefs.json()["items"])

    # 관제탑 동의 없이 노선 공유만 시도하면 거절
    bad = client.put(
        "/v1/shuttle/route-share/consent",
        headers=seeker,
        json={
            "company_key": "9999999999",
            "opted_in": True,
            "tower_participation_consented": False,
        },
    )
    assert bad.status_code == 400
