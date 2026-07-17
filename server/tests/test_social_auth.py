"""Social OAuth tests."""

from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.social_auth_service import exchange_code_for_profile

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


def test_mock_code_is_rejected_when_mock_mode_disabled():
    """보안 회귀 테스트 — mock 비활성화(운영 환경) 상태에서 'mock_' 코드를 보내면
    실제 프로바이더 토큰 교환 없이 가짜 프로필이 발급되는 우회를 막는다.
    (실제 카카오 서버 호출 없이, 우회 경로를 타지 않고 실제 프로바이더 교환
    경로까지 도달하는지만 확인한다.)"""
    sentinel = RuntimeError("reached real provider exchange path")
    with patch(
        "app.services.social_auth_service.social_mock_enabled",
        return_value=False,
    ), patch(
        "app.services.social_auth_service._kakao_profile",
        side_effect=sentinel,
    ):
        with pytest.raises(RuntimeError, match="reached real provider exchange path"):
            exchange_code_for_profile(provider="kakao", code="mock_kakao")


def test_mock_code_is_accepted_when_mock_mode_enabled():
    profile = exchange_code_for_profile(provider="kakao", code="mock_kakao")
    assert profile.provider == "kakao"
    assert profile.provider_user_id.startswith("mock_kakao_")
