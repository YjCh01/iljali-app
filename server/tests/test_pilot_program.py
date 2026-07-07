"""Pilot program — bus location tower designation."""

import json
from datetime import datetime
from zoneinfo import ZoneInfo

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.job_sync_models import JobApplicationRow
from app.main import app
from app.qc_models import QcMemberRow

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}
SEEKER_EMAIL = "seeker-0001@qc.iljari.co.kr"
OTHER_EMAIL = "seeker-0002@qc.iljari.co.kr"
COMPANY_KEY = "5403100894"
ROUTE_ID = "route_daiso_sejong"
TODAY = datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()


def _refresh_today_rider_application(db) -> None:
    today = datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()
    row = db.get(JobApplicationRow, "app_pilot_rider_today")
    if row is None:
        db.add(
            JobApplicationRow(
                id="app_pilot_rider_today",
                post_id="post_pilot_today",
                post_title="셔틀 파일럿",
                company_name="아라컴퍼니",
                company_key=COMPANY_KEY,
                seeker_email=OTHER_EMAIL,
                seeker_name="OTHER SEEKER",
                status="scheduled",
                work_schedule="주간",
                commute_route_id=ROUTE_ID,
                commute_route_name="세종 물류센터 1호차",
                shuttle_stop_id="stop_1",
                shuttle_stop_label="정부세종청사",
                shuttle_pickup_time="07:30",
                shuttle_shift_date=today,
            )
        )
    else:
        row.shuttle_shift_date = today
        row.commute_route_id = ROUTE_ID
        row.company_key = COMPANY_KEY
        row.status = "scheduled"


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        for email, member_id, name, phone in [
            (SEEKER_EMAIL, "qc_seeker_pilot_1", "PILOT SEEKER", "01011112222"),
            (OTHER_EMAIL, "qc_seeker_pilot_2", "OTHER SEEKER", "01033334444"),
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
            else:
                row.phone = phone
        _refresh_today_rider_application(db)
        db.commit()
    finally:
        db.close()


def _prepare_pilot_test(*, work_start_time: str = "") -> None:
    db = SessionLocal()
    try:
        _refresh_today_rider_application(db)
        db.commit()
    finally:
        db.close()
    payload = {
        "seeker_email": SEEKER_EMAIL,
        "enabled": True,
        "company_key": COMPANY_KEY,
        "company_name": "아라컴퍼니",
        "route_id": ROUTE_ID,
        "route_name": "세종 물류센터 1호차",
    }
    if work_start_time:
        payload["work_start_time"] = work_start_time
    client.put(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        json=payload,
    )


def _seeker_token(email: str = SEEKER_EMAIL) -> str:
    res = client.post(
        "/v1/auth/login",
        json={"email": email, "password": "QcTest1234!"},
    )
    assert res.status_code == 200, res.text
    return res.json()["access_token"]


def test_bus_location_tower_admin_and_seeker_status():
    _prepare_pilot_test()
    save = client.get(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
    )
    assert save.status_code == 200, save.text
    body = save.json()
    assert body["seeker_email"] == SEEKER_EMAIL
    assert body["enabled"] is True
    assert body["seeker_display_name"] == "PILOT SEEKER"
    assert body["authorized_rider_count"] == 1

    client.put(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        json={
            "seeker_email": SEEKER_EMAIL,
            "enabled": True,
            "company_key": COMPANY_KEY,
            "company_name": "아라컴퍼니",
            "route_id": ROUTE_ID,
            "route_name": "세종 물류센터 1호차",
            "note": "QC pilot",
        },
    )

    admin = client.get(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
    )
    assert admin.status_code == 200
    assert admin.json()["note"] == "QC pilot"

    token = _seeker_token()
    designated = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert designated.status_code == 200, designated.text
    status = designated.json()
    assert status["is_designated"] is True
    assert status["enabled"] is True
    assert status["viewer_role"] == "driver"
    assert status["can_share_location"] is True
    assert "실시간 셔틀 위치" in status["title"]

    other_token = _seeker_token(OTHER_EMAIL)
    other = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert other.status_code == 200
    assert other.json()["is_designated"] is False
    assert other.json()["is_authorized_rider"] is True
    assert other.json()["enabled"] is True
    assert other.json()["viewer_role"] == "rider"


def test_bus_location_tower_disabled_hides_from_seeker():
    client.put(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        json={
            "seeker_email": SEEKER_EMAIL,
            "enabled": False,
            "company_key": COMPANY_KEY,
            "route_id": ROUTE_ID,
        },
    )
    token = _seeker_token()
    res = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.status_code == 200
    assert res.json()["is_designated"] is False


def test_bus_location_tower_location_consent_flag():
    db = SessionLocal()
    try:
        row = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.email == SEEKER_EMAIL)
            .first()
        )
        row.seeker_profile_json = json.dumps(
            {"locationConsentAcceptedAt": "2026-06-19T00:00:00Z"}
        )
        db.commit()
    finally:
        db.close()

    client.put(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
        json={
            "seeker_email": SEEKER_EMAIL,
            "enabled": True,
            "company_key": COMPANY_KEY,
            "company_name": "아라컴퍼니",
            "route_id": ROUTE_ID,
            "route_name": "세종 물류센터 1호차",
        },
    )
    admin = client.get(
        "/v1/admin/ops/pilot/bus-location-tower",
        headers=ADMIN_HEADERS,
    )
    assert admin.json()["location_consent_granted"] is True

    token = _seeker_token()
    res = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert res.json()["location_consent_granted"] is True


def test_bus_location_tower_search_candidates_by_phone():
    search = client.get(
        "/v1/admin/ops/pilot/bus-location-tower/candidates",
        headers=ADMIN_HEADERS,
        params={"phone": "010-1111-2222"},
    )
    assert search.status_code == 200, search.text
    body = search.json()
    assert body["count"] == 1
    assert body["candidates"][0]["email"] == SEEKER_EMAIL

    empty = client.get(
        "/v1/admin/ops/pilot/bus-location-tower/candidates",
        headers=ADMIN_HEADERS,
        params={"phone": "01099998888"},
    )
    assert empty.status_code == 200
    assert empty.json()["count"] == 0


def test_bus_location_tower_work_start_stops_tracking():
    _prepare_pilot_test(work_start_time="00:01")
    driver_token = _seeker_token(SEEKER_EMAIL)
    update = client.post(
        "/v1/pilot/bus-location-tower/location",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={"latitude": 36.5, "longitude": 127.25},
    )
    assert update.status_code == 403, update.text

    rider_token = _seeker_token(OTHER_EMAIL)
    rider = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {rider_token}"},
    )
    assert rider.status_code == 200
    body = rider.json()
    assert body["phase"] == "arrived_at_workplace"
    assert body["tracking_stopped_reason"] == "work_start_arrived"
    assert body["can_track_location"] is False


def test_bus_location_tower_driver_updates_rider_tracks_location():
    _prepare_pilot_test(work_start_time="23:59")
    driver_token = _seeker_token(SEEKER_EMAIL)
    update = client.post(
        "/v1/pilot/bus-location-tower/location",
        headers={"Authorization": f"Bearer {driver_token}"},
        json={"latitude": 36.5, "longitude": 127.25, "accuracy_m": 8.5},
    )
    assert update.status_code == 200, update.text
    assert update.json()["today_session"]["last_latitude"] == 36.5

    rider_token = _seeker_token(OTHER_EMAIL)
    rider = client.get(
        "/v1/pilot/bus-location-tower/me",
        headers={"Authorization": f"Bearer {rider_token}"},
    )
    assert rider.status_code == 200
    assert rider.json()["can_track_location"] is True
    assert rider.json()["today_session"]["last_longitude"] == 127.25

    forbidden = client.post(
        "/v1/pilot/bus-location-tower/location",
        headers={"Authorization": f"Bearer {rider_token}"},
        json={"latitude": 36.6, "longitude": 127.3},
    )
    assert forbidden.status_code == 403
