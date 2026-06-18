from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_job_board_crud():
    created = client.post(
        "/v1/job-board/posts",
        json={
            "title": "물류 보조",
            "company_name": "테스트물류",
            "company_key": "1234567890",
            "hourly_wage": "시급 12000",
        },
    )
    assert created.status_code == 200
    post_id = created.json()["id"]

    listed = client.get("/v1/job-board/posts")
    assert listed.status_code == 200
    assert listed.json()["count"] >= 1

    updated = client.put(
        f"/v1/job-board/posts/{post_id}",
        json={"status": "closed"},
    )
    assert updated.status_code == 200
    assert updated.json()["status"] == "closed"


def test_hiring_and_chat():
    app_row = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_test",
            "seeker_email": "seeker@test.iljari.co.kr",
            "seeker_name": "구직자",
        },
    )
    assert app_row.status_code == 200
    app_id = app_row.json()["id"]

    msg = client.post(
        f"/v1/chat-sync/{app_id}/messages",
        json={"sender_role": "seeker", "body": "안녕하세요"},
    )
    assert msg.status_code == 200

    messages = client.get(f"/v1/chat-sync/{app_id}/messages")
    assert messages.status_code == 200
    assert len(messages.json()["messages"]) == 1
