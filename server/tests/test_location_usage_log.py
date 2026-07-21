from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine, SessionLocal
from app.main import app
from app.services.auth_token_service import issue_token
from app.services.location_usage_log_service import list_usage_logs, record_usage

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def _seeker_headers(email: str = "seeker-loc@test.iljari.co.kr") -> dict[str, str]:
    token = issue_token({"sub": email, "member_type": "seeker"})
    return {"Authorization": f"Bearer {token}"}


def _employer_headers(company_key: str = "1234567890") -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-loc@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_record_usage_and_list_usage_logs_service():
    db = SessionLocal()
    try:
        record_usage(
            db,
            usage_type="map_view",
            subject_label="구직자(개인회원)",
            subject_email="svc-test@test.iljari.co.kr",
            acquisition_path="이용자 단말 OS 위치서비스",
            service_description="지도상 공고 위치 표시",
            recipient_label="본인(서비스 화면)",
            latitude=37.5,
            longitude=127.0,
            detail={"post_id": "post_1"},
        )
        logs = list_usage_logs(db, usage_type="map_view", limit=10)
        assert any(row["subject_email"] == "svc-test@test.iljari.co.kr" for row in logs)
        matched = next(row for row in logs if row["subject_email"] == "svc-test@test.iljari.co.kr")
        assert matched["latitude"] == 37.5
        assert matched["detail"]["post_id"] == "post_1"
    finally:
        db.close()


def test_attendance_verification_log_requires_auth():
    response = client.post(
        "/v1/compliance/attendance-verification-log",
        json={
            "application_id": "app_1",
            "role": "seeker",
            "allowed": True,
            "within_geofence": True,
        },
    )
    assert response.status_code == 401


def test_attendance_verification_log_records_checkin_usage():
    headers = _seeker_headers("checkin-seeker@test.iljari.co.kr")
    response = client.post(
        "/v1/compliance/attendance-verification-log",
        headers=headers,
        json={
            "application_id": "app_checkin_1",
            "role": "seeker",
            "allowed": True,
            "within_geofence": True,
            "distance_meters": 42.5,
            "is_mocked": False,
            "reason": "within_geofence",
            "latitude": 37.55,
            "longitude": 127.05,
            "company_key": "1234567890",
        },
    )
    assert response.status_code == 200
    assert response.json() == {"ok": True}

    admin_response = client.get(
        "/v1/admin/ops/location-usage-logs",
        headers=ADMIN_HEADERS,
        params={"usage_type": "checkin_verify"},
    )
    assert admin_response.status_code == 200
    logs = admin_response.json()["logs"]
    matched = next(
        row for row in logs if row["subject_email"] == "checkin-seeker@test.iljari.co.kr"
    )
    assert matched["usage_type"] == "checkin_verify"
    assert matched["detail"]["application_id"] == "app_checkin_1"
    assert matched["detail"]["distance_meters"] == 42.5
    assert matched["latitude"] == 37.55


def test_admin_location_usage_logs_requires_admin_key():
    response = client.get("/v1/admin/ops/location-usage-logs")
    assert response.status_code in (401, 403)


def test_map_impression_records_usage_log():
    headers = _employer_headers("9876543210")
    client.post(
        "/v1/job-board/posts",
        headers=headers,
        json={
            "id": "loc_map_post_1",
            "title": "지도 노출 테스트 공고",
            "company_name": "테스트물류",
            "company_key": "9876543210",
            "workplace_latitude": 37.4,
            "workplace_longitude": 127.1,
        },
    )
    response = client.post(
        "/v1/job-board/posts/loc_map_post_1/map-impression",
        params={"seeker_email": "map-seeker@test.iljari.co.kr"},
    )
    assert response.status_code == 200

    admin_response = client.get(
        "/v1/admin/ops/location-usage-logs",
        headers=ADMIN_HEADERS,
        params={"usage_type": "map_view"},
    )
    logs = admin_response.json()["logs"]
    matched = next(
        row for row in logs if row["subject_email"] == "map-seeker@test.iljari.co.kr"
    )
    assert matched["detail"]["post_id"] == "loc_map_post_1"
    assert matched["latitude"] == 37.4
