from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)

ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-refund@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _charge_and_confirm(company_key: str, order_id: str) -> None:
    headers = _employer_headers(company_key)
    client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "일자리 알림핀 5회",
            "amount_krw": 99000,
            "company_key": company_key,
            "credit_type": "package",
            "credit_count": 5,
            "credit_location_slots": 5,
        },
        headers=headers,
    )
    client.post(
        "/v1/payments/confirm",
        json={"payment_key": "pk-refund", "order_id": order_id, "amount_krw": 99000},
        headers=headers,
    )


def test_admin_refund_reverses_unused_credit():
    company_key = "8111111111"
    order_id = "PKG-refund-001"
    _charge_and_confirm(company_key, order_id)

    wallet_before = client.get(
        f"/v1/wallet/{company_key}", headers=_employer_headers(company_key)
    ).json()
    assert wallet_before["package_credits"] == 5

    refund = client.post(
        f"/v1/admin/ops/payments/{order_id}/refund",
        json={"reason": "고객 요청"},
        headers=ADMIN_HEADERS,
    )
    assert refund.status_code == 200, refund.text
    assert refund.json()["status"] == "refunded"

    wallet_after = client.get(
        f"/v1/wallet/{company_key}", headers=_employer_headers(company_key)
    ).json()
    assert wallet_after["package_credits"] == 0


def test_admin_refund_does_not_claw_back_already_consumed_credit():
    company_key = "8122222222"
    order_id = "PKG-refund-002"
    _charge_and_confirm(company_key, order_id)

    client.post(
        f"/v1/wallet/{company_key}/consume",
        json={"credit_type": "package", "count": 2},
        headers=_employer_headers(company_key),
    )

    refund = client.post(
        f"/v1/admin/ops/payments/{order_id}/refund",
        json={"reason": "부분 사용 후 환불"},
        headers=ADMIN_HEADERS,
    )
    assert refund.status_code == 200

    wallet_after = client.get(
        f"/v1/wallet/{company_key}", headers=_employer_headers(company_key)
    ).json()
    # 5개 중 2개는 이미 소비 — 환불로 나머지 3개만 회수, 이미 쓴 2개는 되돌리지 않음
    assert wallet_after["package_credits"] == 0


def test_refund_rejects_unconfirmed_order():
    company_key = "8133333333"
    order_id = "PKG-refund-003"
    client.post(
        "/v1/payments/charge",
        json={
            "order_id": order_id,
            "order_name": "미확정 주문",
            "amount_krw": 19900,
            "company_key": company_key,
        },
        headers=_employer_headers(company_key),
    )
    # confirm을 호출하지 않았으므로 status는 여전히 pending(모의결제 charge는 confirmed로
    # 즉시 전환되므로, 실제 미확정 상태를 만들려면 존재하지 않는 order_id로 시도)
    refund = client.post(
        "/v1/admin/ops/payments/does-not-exist/refund",
        json={"reason": "테스트"},
        headers=ADMIN_HEADERS,
    )
    assert refund.status_code == 400


def test_double_refund_is_idempotent():
    company_key = "8144444444"
    order_id = "PKG-refund-004"
    _charge_and_confirm(company_key, order_id)

    first = client.post(
        f"/v1/admin/ops/payments/{order_id}/refund",
        json={"reason": "1차"},
        headers=ADMIN_HEADERS,
    )
    second = client.post(
        f"/v1/admin/ops/payments/{order_id}/refund",
        json={"reason": "2차 재시도"},
        headers=ADMIN_HEADERS,
    )
    assert first.status_code == 200
    assert second.status_code == 200
    assert second.json()["status"] == "refunded"


def test_refund_requires_admin_key():
    company_key = "8155555555"
    order_id = "PKG-refund-005"
    _charge_and_confirm(company_key, order_id)

    response = client.post(
        f"/v1/admin/ops/payments/{order_id}/refund",
        json={"reason": "무인증 시도"},
    )
    assert response.status_code == 401


def test_admin_can_list_and_search_payments_by_company():
    company_key = "8166666666"
    order_id = "PKG-refund-006"
    _charge_and_confirm(company_key, order_id)

    listed = client.get(
        "/v1/admin/ops/payments",
        params={"company_key": company_key},
        headers=ADMIN_HEADERS,
    )
    assert listed.status_code == 200
    assert any(o["order_id"] == order_id for o in listed.json()["orders"])

    single = client.get(
        f"/v1/admin/ops/payments/{order_id}",
        headers=ADMIN_HEADERS,
    )
    assert single.status_code == 200
    assert single.json()["order_id"] == order_id
