from unittest.mock import patch

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def _seeker_headers(seeker_email: str) -> dict[str, str]:
    token = issue_token({"sub": seeker_email, "member_type": "seeker"})
    return {"Authorization": f"Bearer {token}"}


def test_status_transition_to_scheduled_fires_work_schedule_confirmed_push():
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_confirm_push_1",
            "post_title": "테스트 공고",
            "seeker_email": "seeker-confirm-push-1@qc.iljari.co.kr",
            "seeker_name": "지원자",
            "status": "applied",
        },
        headers=_seeker_headers("seeker-confirm-push-1@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text
    application_id = resp.json()["id"]

    with patch(
        "app.routers.hiring.push_work_schedule_confirmed"
    ) as mock_push:
        resp = client.post(
            "/v1/hiring/applications",
            json={
                "post_id": "post_confirm_push_1",
                "seeker_email": "seeker-confirm-push-1@qc.iljari.co.kr",
                "status": "scheduled",
            },
            headers=_seeker_headers("seeker-confirm-push-1@qc.iljari.co.kr"),
        )
    assert resp.status_code == 200, resp.text
    assert mock_push.call_count == 1
    assert mock_push.call_args.kwargs["application_id"] == application_id


def test_status_already_scheduled_does_not_refire_push():
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_confirm_push_2",
            "post_title": "테스트 공고",
            "seeker_email": "seeker-confirm-push-2@qc.iljari.co.kr",
            "seeker_name": "지원자",
            "status": "scheduled",
        },
        headers=_seeker_headers("seeker-confirm-push-2@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text

    with patch(
        "app.routers.hiring.push_work_schedule_confirmed"
    ) as mock_push:
        resp = client.post(
            "/v1/hiring/applications",
            json={
                "post_id": "post_confirm_push_2",
                "seeker_email": "seeker-confirm-push-2@qc.iljari.co.kr",
                "status": "scheduled",
                "work_schedule": "10:00-19:00",
            },
            headers=_seeker_headers("seeker-confirm-push-2@qc.iljari.co.kr"),
        )
    assert resp.status_code == 200, resp.text
    mock_push.assert_not_called()


def test_setting_interview_at_for_the_first_time_fires_interview_confirmed_push():
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_confirm_push_3",
            "post_title": "테스트 공고",
            "seeker_email": "seeker-confirm-push-3@qc.iljari.co.kr",
            "seeker_name": "지원자",
            "status": "applied",
        },
        headers=_seeker_headers("seeker-confirm-push-3@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text
    application_id = resp.json()["id"]

    with patch("app.routers.hiring.push_interview_confirmed") as mock_push:
        resp = client.post(
            "/v1/hiring/applications",
            json={
                "post_id": "post_confirm_push_3",
                "seeker_email": "seeker-confirm-push-3@qc.iljari.co.kr",
                "status": "applied",
                "interview_at": "2026-08-01T10:00:00",
            },
            headers=_seeker_headers("seeker-confirm-push-3@qc.iljari.co.kr"),
        )
    assert resp.status_code == 200, resp.text
    assert mock_push.call_count == 1
    assert mock_push.call_args.kwargs["application_id"] == application_id


def test_changing_already_set_interview_at_does_not_refire_push():
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_confirm_push_4",
            "post_title": "테스트 공고",
            "seeker_email": "seeker-confirm-push-4@qc.iljari.co.kr",
            "seeker_name": "지원자",
            "status": "applied",
            "interview_at": "2026-08-01T10:00:00",
        },
        headers=_seeker_headers("seeker-confirm-push-4@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text

    with patch("app.routers.hiring.push_interview_confirmed") as mock_push:
        resp = client.post(
            "/v1/hiring/applications",
            json={
                "post_id": "post_confirm_push_4",
                "seeker_email": "seeker-confirm-push-4@qc.iljari.co.kr",
                "status": "applied",
                "interview_at": "2026-08-02T11:00:00",
            },
            headers=_seeker_headers("seeker-confirm-push-4@qc.iljari.co.kr"),
        )
    assert resp.status_code == 200, resp.text
    mock_push.assert_not_called()
