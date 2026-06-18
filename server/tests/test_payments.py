from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_mock_charge_and_confirm():
    order_id = "PKG-test-001"
    charge = client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "푸시·거점 패키지",
            "amount_krw": 5000,
            "company_key": "1234567890",
        },
    )
    assert charge.status_code == 200
    body = charge.json()
    assert body["success"] is True
    assert body["mock"] is True

    confirm = client.post(
        "/v1/payments/confirm",
        json={
            "payment_key": "test-key",
            "order_id": order_id,
            "amount_krw": 5000,
        },
    )
    assert confirm.status_code == 200
    assert confirm.json()["success"] is True

    order = client.get(f"/v1/payments/orders/{order_id}")
    assert order.status_code == 200
    assert order.json()["status"] == "confirmed"
