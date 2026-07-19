from unittest.mock import patch

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services import rate_limiter
from app.services.rate_limiter import check_rate_limit, reset_all

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def setup_function():
    reset_all()


def test_allows_calls_under_the_limit():
    for _ in range(3):
        assert check_rate_limit("k1", max_calls=3, window_sec=60) is True


def test_blocks_calls_over_the_limit():
    for _ in range(3):
        assert check_rate_limit("k2", max_calls=3, window_sec=60) is True
    assert check_rate_limit("k2", max_calls=3, window_sec=60) is False


def test_window_expiry_resets_the_count(monkeypatch):
    fake_time = [1000.0]
    monkeypatch.setattr(rate_limiter.time, "monotonic", lambda: fake_time[0])

    assert check_rate_limit("k3", max_calls=2, window_sec=10) is True
    assert check_rate_limit("k3", max_calls=2, window_sec=10) is True
    assert check_rate_limit("k3", max_calls=2, window_sec=10) is False

    fake_time[0] += 11
    assert check_rate_limit("k3", max_calls=2, window_sec=10) is True


def test_keys_are_independent():
    assert check_rate_limit("a", max_calls=1, window_sec=60) is True
    assert check_rate_limit("b", max_calls=1, window_sec=60) is True
    assert check_rate_limit("a", max_calls=1, window_sec=60) is False


def test_login_endpoint_returns_429_once_bypass_is_disabled():
    """운영 환경(비-pytest)에서 실제로 로그인 라우트가 429를 반환하는지 종단 검증."""
    with patch("app.services.rate_limiter._bypassed_for_tests", return_value=False):
        last = None
        for _ in range(11):
            last = client.post(
                "/v1/auth/login",
                json={"email": "rl-test@qc.iljari.co.kr", "password": "wrong"},
            )
        assert last.status_code == 429
