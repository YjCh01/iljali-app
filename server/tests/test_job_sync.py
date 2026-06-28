from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


from app.services.auth_token_service import issue_token


def _corp_auth_headers(company_key: str = "1234567890") -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_job_board_crud():
    headers = _corp_auth_headers()
    created = client.post(
        "/v1/job-board/posts",
        headers=headers,
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
        headers=headers,
        json={"status": "closed"},
    )
    assert updated.status_code == 200
    assert updated.json()["status"] == "closed"


def test_job_board_rejects_cross_company_update():
    owner_headers = _corp_auth_headers("1234567890")
    other_headers = _corp_auth_headers("9876543210")
    created = client.post(
        "/v1/job-board/posts",
        headers=owner_headers,
        json={
            "title": "타사 공고",
            "company_key": "1234567890",
        },
    )
    assert created.status_code == 200
    post_id = created.json()["id"]

    denied = client.put(
        f"/v1/job-board/posts/{post_id}",
        headers=other_headers,
        json={"status": "closed"},
    )
    assert denied.status_code == 403


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
