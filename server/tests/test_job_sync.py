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


def _seeker_auth_headers(email: str) -> dict[str, str]:
    token = issue_token({"sub": email, "member_type": "seeker"})
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


def test_chat_websocket_broadcast():
    app_row = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_ws",
            "seeker_email": "ws@test.iljari.co.kr",
            "seeker_name": "실시간",
        },
    )
    assert app_row.status_code == 200
    app_id = app_row.json()["id"]

    with client.websocket_connect(
        f"/v1/chat-sync/ws/{app_id}?role=employer"
    ) as ws:
        hello = ws.receive_json()
        assert hello["type"] == "connected"
        assert hello["application_id"] == app_id

        posted = client.post(
            f"/v1/chat-sync/{app_id}/messages",
            json={"sender_role": "seeker", "body": "실시간 테스트"},
        )
        assert posted.status_code == 200

        pushed = ws.receive_json()
        assert pushed["type"] == "message"
        assert pushed["payload"]["body"] == "실시간 테스트"


def test_withdraw_application_removes_from_bootstrap():
    email = "withdraw@test.iljari.co.kr"
    post_id = "post_withdraw_line"
    headers = _seeker_auth_headers(email)
    created = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": post_id,
            "post_title": "라인헬스케어",
            "seeker_email": email,
            "seeker_name": "최영진",
        },
    )
    assert created.status_code == 200

    boot_before = client.get(
        "/v1/sync/bootstrap",
        params={"seeker_email": email},
        headers=headers,
    )
    assert boot_before.status_code == 200
    assert boot_before.json()["counts"]["applications"] >= 1

    withdrawn = client.delete(
        "/v1/hiring/applications",
        params={"post_id": post_id, "seeker_email": email},
        headers=headers,
    )
    assert withdrawn.status_code == 200
    assert withdrawn.json()["withdrawn"] is True
    assert withdrawn.json()["deleted"] >= 1

    boot_after = client.get(
        "/v1/sync/bootstrap",
        params={"seeker_email": email},
        headers=headers,
    )
    assert boot_after.status_code == 200
    apps = boot_after.json()["applications"]
    assert not any(a["post_id"] == post_id for a in apps)


def test_list_applications_requires_auth():
    resp = client.get(
        "/v1/hiring/applications", params={"seeker_email": "leak@test.iljari.co.kr"}
    )
    assert resp.status_code == 401


def test_list_applications_requires_at_least_one_filter():
    resp = client.get(
        "/v1/hiring/applications",
        headers=_seeker_auth_headers("someone@test.iljari.co.kr"),
    )
    assert resp.status_code == 400


def test_list_applications_rejects_other_seekers_email():
    email = "victim@test.iljari.co.kr"
    client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_leak_check",
            "post_title": "테스트 공고",
            "seeker_email": email,
            "seeker_name": "피해자",
        },
    )
    resp = client.get(
        "/v1/hiring/applications",
        params={"seeker_email": email},
        headers=_seeker_auth_headers("attacker@test.iljari.co.kr"),
    )
    assert resp.status_code == 403


def test_list_applications_allows_the_seeker_themself():
    email = "self-view@test.iljari.co.kr"
    client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_self_view",
            "post_title": "테스트 공고",
            "seeker_email": email,
            "seeker_name": "본인",
        },
    )
    resp = client.get(
        "/v1/hiring/applications",
        params={"seeker_email": email},
        headers=_seeker_auth_headers(email),
    )
    assert resp.status_code == 200
    assert resp.json()["count"] >= 1


def test_sync_bootstrap_requires_auth_when_seeker_email_given():
    resp = client.get(
        "/v1/sync/bootstrap", params={"seeker_email": "leak2@test.iljari.co.kr"}
    )
    assert resp.status_code == 401


def test_sync_bootstrap_works_without_auth_for_guest_browsing():
    resp = client.get("/v1/sync/bootstrap")
    assert resp.status_code == 200
    assert "posts" in resp.json()


def test_withdraw_application_requires_auth():
    resp = client.delete(
        "/v1/hiring/applications",
        params={"post_id": "post_x", "seeker_email": "victim2@test.iljari.co.kr"},
    )
    assert resp.status_code == 401


def test_sync_member_sanction_requires_matching_email():
    email = "sanction-self@test.iljari.co.kr"
    resp = client.get(
        "/v1/sync/member/sanction",
        params={"email": email},
        headers=_seeker_auth_headers("other@test.iljari.co.kr"),
    )
    assert resp.status_code == 403

    resp_ok = client.get(
        "/v1/sync/member/sanction",
        params={"email": email},
        headers=_seeker_auth_headers(email),
    )
    assert resp_ok.status_code == 200
