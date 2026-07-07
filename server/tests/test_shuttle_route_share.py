"""Shuttle route share — hire offer and consent."""

from datetime import datetime, timezone

from fastapi.testclient import TestClient

from app.database import SessionLocal
from app.job_sync_models import JobApplicationRow
from app.main import app
from app.shuttle_models import ShuttleRouteShareConsentRow

client = TestClient(app)

SEEKER = "shuttle_seeker@example.com"
APP_ID = "app_shuttle_share_test"
COMPANY_KEY = "1234567890"


def _seed_application(db):
    row = db.get(JobApplicationRow, APP_ID)
    if row is None:
        db.add(
            JobApplicationRow(
                id=APP_ID,
                post_id="post_1",
                post_title="물류 알바",
                company_name="테스트 물류",
                company_key=COMPANY_KEY,
                seeker_email=SEEKER,
                seeker_name="홍길동",
                status="scheduled",
                applied_at=datetime.now(timezone.utc),
            )
        )
        db.commit()


def _seeker_token() -> str:
    from app.services.auth_token_service import issue_token

    return issue_token({"sub": SEEKER, "member_type": "seeker"})


def test_shuttle_route_share_offer_and_consent():
    db = SessionLocal()
    try:
        _seed_application(db)
    finally:
        db.close()

    token = _seeker_token()
    headers = {"Authorization": f"Bearer {token}"}

    offer = client.post(
        "/v1/shuttle/route-share/offer",
        headers=headers,
        json={
            "application_id": APP_ID,
            "company_key": COMPANY_KEY,
            "company_name": "테스트 물류",
            "route_count": 2,
        },
    )
    assert offer.status_code == 200, offer.text
    assert offer.json()["company_key"] == COMPANY_KEY

    listed = client.get("/v1/shuttle/route-share/me", headers=headers)
    assert listed.status_code == 200
    assert len(listed.json()["items"]) >= 1

    consent = client.put(
        "/v1/shuttle/route-share/consent",
        headers=headers,
        json={
            "company_key": COMPANY_KEY,
            "opted_in": True,
            "tower_participation_consented": True,
            "route_id": "route_a",
            "stop_id": "stop_1",
            "pickup_time": "07:30",
        },
    )
    assert consent.status_code == 200, consent.text
    body = consent.json()
    assert body["opted_in"] is True
    assert body["tower_participation_consented"] is True
    assert body["route_id"] == "route_a"

    db = SessionLocal()
    try:
        row = db.get(
            ShuttleRouteShareConsentRow,
            f"{SEEKER}|{COMPANY_KEY}",
        )
        assert row is not None
        assert row.opted_in is True
    finally:
        db.close()


def test_shuttle_consent_requires_tower_when_opted_in():
    token = _seeker_token()
    headers = {"Authorization": f"Bearer {token}"}
    bad = client.put(
        "/v1/shuttle/route-share/consent",
        headers=headers,
        json={
            "company_key": COMPANY_KEY,
            "opted_in": True,
            "tower_participation_consented": False,
        },
    )
    assert bad.status_code == 400
