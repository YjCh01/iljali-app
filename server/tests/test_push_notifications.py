from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def _seeker_headers() -> dict[str, str]:
    token = issue_token(
        {
            "sub": "seeker-push@test.iljari.co.kr",
            "member_type": "seeker",
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_register_push_device():
    response = client.post(
        "/v1/notifications/devices/register",
        headers=_seeker_headers(),
        json={
            "fcm_token": "test_fcm_token_seeker_001",
            "platform": "web",
            "chat_enabled": True,
            "job_alerts_enabled": True,
        },
    )
    assert response.status_code == 200
    body = response.json()
    assert body["device"]["member_email"] == "seeker-push@test.iljari.co.kr"
    assert "fcm_enabled" in body


def test_notification_status():
    response = client.get("/v1/notifications/status")
    assert response.status_code == 200
    assert "fcm_enabled" in response.json()
