"""Social OAuth tests."""

from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


def test_social_status_mock_mode():
    res = client.get("/v1/auth/social/status")
    assert res.status_code == 200
    body = res.json()
    assert "providers" in body
    assert body["providers"]["kakao"] is True


def test_social_start_redirects_in_mock_mode():
    res = client.get(
        "/v1/auth/social/kakao/start",
        params={"member_type": "seeker", "app_redirect": "https://iljari.app/auth/social-complete"},
        follow_redirects=False,
    )
    assert res.status_code == 302
    location = res.headers.get("location", "")
    assert "callback" in location
    assert "mock_kakao" in location


def test_social_callback_signup_needed():
    start = client.get(
        "/v1/auth/social/kakao/start",
        params={"member_type": "seeker", "app_redirect": "https://iljari.app/auth/social-complete"},
        follow_redirects=False,
    )
    assert start.status_code == 302
    callback = client.get(start.headers["location"], follow_redirects=False)
    assert callback.status_code == 302
    final = callback.headers["location"]
    assert "signup_needed" in final
    assert "social_token=" in final
