from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.push_wallet_models import PushWalletCreditLotRow
from app.services.push_wallet_service import get_or_create_wallet, grant_credit_lot

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_charge_then_confirm_grants_credit_once():
    company_key = "1111111111"
    order_id = "PKG-grant-001"
    client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "일자리 알림핀 10회",
            "amount_krw": 179100,
            "company_key": company_key,
            "credit_type": "package",
            "credit_count": 10,
            "credit_location_slots": 10,
        },
    )

    confirm = client.post(
        "/v1/payments/confirm",
        json={"payment_key": "pk-1", "order_id": order_id, "amount_krw": 179100},
    )
    assert confirm.status_code == 200

    wallet = client.get(f"/v1/wallet/{company_key}").json()
    assert wallet["package_credits"] == 10
    assert wallet["location_slots_from_packages"] == 10


def test_duplicate_confirm_does_not_double_credit():
    company_key = "2222222222"
    order_id = "PKG-grant-002"
    client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "PUSH 이용권",
            "amount_krw": 19900,
            "company_key": company_key,
            "credit_type": "push_ticket",
            "credit_count": 1,
        },
    )

    confirm_body = {"payment_key": "pk-2", "order_id": order_id, "amount_krw": 19900}
    first = client.post("/v1/payments/confirm", json=confirm_body)
    assert first.status_code == 200
    # 네트워크 재시도로 인한 동일 confirm 재호출
    second = client.post("/v1/payments/confirm", json=confirm_body)
    assert second.status_code == 200

    wallet = client.get(f"/v1/wallet/{company_key}").json()
    assert wallet["push_ticket_credits"] == 1

    lots = (
        SessionLocal()
        .query(PushWalletCreditLotRow)
        .filter(PushWalletCreditLotRow.source_order_id == order_id)
        .all()
    )
    assert len(lots) == 1


def test_webhook_grants_credit_when_confirm_never_called():
    """클라이언트의 confirm 호출이 유실돼도 웹훅이 도착하면 크레딧이 지급된다."""
    company_key = "3333333333"
    order_id = "PKG-grant-003"
    client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "노출+PUSH 번들",
            "amount_krw": 19900,
            "company_key": company_key,
            "credit_type": "exposure_bundle",
            "credit_count": 1,
        },
    )

    webhook_body = (
        '{"eventType": "DONE", "orderId": "%s", "paymentKey": "pk-3"}' % order_id
    ).encode()
    response = client.post(
        "/v1/payments/webhook/toss",
        content=webhook_body,
        headers={"Content-Type": "application/json"},
    )
    assert response.status_code == 200

    wallet = client.get(f"/v1/wallet/{company_key}").json()
    assert wallet["exposure_push_bundle_credits"] == 1


def test_webhook_after_client_confirm_does_not_double_credit():
    company_key = "3939393939"
    order_id = "PKG-grant-004"
    client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "일자리 알림핀 1회",
            "amount_krw": 19900,
            "company_key": company_key,
            "credit_type": "package",
            "credit_count": 1,
            "credit_location_slots": 1,
        },
    )
    client.post(
        "/v1/payments/confirm",
        json={"payment_key": "pk-4", "order_id": order_id, "amount_krw": 19900},
    )
    webhook_body = (
        '{"eventType": "DONE", "orderId": "%s", "paymentKey": "pk-4"}' % order_id
    ).encode()
    client.post(
        "/v1/payments/webhook/toss",
        content=webhook_body,
        headers={"Content-Type": "application/json"},
    )

    wallet = client.get(f"/v1/wallet/{company_key}").json()
    assert wallet["package_credits"] == 1


def test_wallet_credits_endpoint_idempotent_on_order_id():
    company_key = "4444444444"
    body = {"count": 5, "location_slots": 5, "order_id": "ADMIN-ORDER-1"}
    first = client.post(f"/v1/wallet/{company_key}/credits", json=body)
    second = client.post(f"/v1/wallet/{company_key}/credits", json=body)
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["package_credits"] == 5


def test_expired_lot_is_swept_from_balance():
    company_key = "5555555555"
    db = SessionLocal()
    wallet = get_or_create_wallet(db, company_key)
    wallet.package_credits = 3
    wallet.location_slots_from_packages = 3
    db.add(
        PushWalletCreditLotRow(
            company_key=company_key,
            credit_type="package",
            count=3,
            remaining=3,
            expires_at=datetime.utcnow() - timedelta(days=1),
            source_order_id="EXPIRED-ORDER-1",
        )
    )
    db.commit()
    db.close()

    wallet_json = client.get(f"/v1/wallet/{company_key}").json()
    assert wallet_json["package_credits"] == 0
    assert wallet_json["location_slots_from_packages"] == 0


def test_legacy_lot_without_expiry_is_never_swept():
    company_key = "6666666666"
    db = SessionLocal()
    grant_credit_lot(
        db,
        company_key,
        "package",
        count=7,
        location_slots=7,
        valid_days=None,
        source_order_id=None,
    )
    db.close()

    wallet_json = client.get(f"/v1/wallet/{company_key}").json()
    assert wallet_json["package_credits"] == 7
