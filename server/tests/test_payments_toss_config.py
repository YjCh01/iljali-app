from app.config import settings
from app.services.payment_service import toss_checkout_url


def test_checkout_url_uses_https_redirects_when_configured(monkeypatch):
    monkeypatch.setattr(
        settings,
        "payment_web_success_url",
        "https://app.staging.iljari.local/payment-success",
    )
    monkeypatch.setattr(
        settings,
        "payment_web_fail_url",
        "https://app.staging.iljari.local/payment-fail",
    )
    monkeypatch.setattr(settings, "toss_client_key", "test_ck_demo")
    url = toss_checkout_url(
        order_id="ORD-1",
        order_name="테스트",
        amount_krw=5000,
        web_checkout=True,
    )
    assert "pay.toss.im" in url
    assert "payment-success" in url
    assert "test_ck_demo" in url
