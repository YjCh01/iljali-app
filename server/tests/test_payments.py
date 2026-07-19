from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-payments@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_mock_charge_and_confirm():
    company_key = "1234567890"
    headers = _employer_headers(company_key)
    order_id = "PKG-test-001"
    charge = client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "푸시·거점 패키지",
            "amount_krw": 5000,
            "company_key": company_key,
        },
        headers=headers,
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
        headers=headers,
    )
    assert confirm.status_code == 200
    assert confirm.json()["success"] is True

    order = client.get(f"/v1/payments/orders/{order_id}", headers=headers)
    assert order.status_code == 200
    assert order.json()["status"] == "confirmed"
