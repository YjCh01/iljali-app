import hashlib
import hmac
import json

from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_toss_webhook_accepts_valid_signature(monkeypatch):
    monkeypatch.setattr(
        "app.routers.payment_webhook.settings.toss_webhook_secret",
        "test-webhook-secret",
    )
    body = json.dumps(
        {"eventType": "DONE", "orderId": "WH-001", "paymentKey": "pk_test"}
    ).encode()
    sig = hmac.new(b"test-webhook-secret", body, hashlib.sha256).hexdigest()
    response = client.post(
        "/v1/payments/webhook/toss",
        content=body,
        headers={"Toss-Signature": sig, "Content-Type": "application/json"},
    )
    assert response.status_code == 200
    assert response.json()["order_id"] == "WH-001"


def test_toss_webhook_rejects_bad_signature(monkeypatch):
    monkeypatch.setattr(
        "app.routers.payment_webhook.settings.toss_webhook_secret",
        "test-webhook-secret",
    )
    response = client.post(
        "/v1/payments/webhook/toss",
        content=b"{}",
        headers={"Toss-Signature": "bad"},
    )
    assert response.status_code == 401
