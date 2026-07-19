"""토스페이먼츠 결제 승인·원장."""

from __future__ import annotations

import base64
from datetime import datetime
from urllib.parse import urlencode

import httpx
from sqlalchemy.orm import Session

from app.config import settings
from app.job_sync_models import PaymentOrderRow
from app.services.push_wallet_service import grant_credit_lot, revoke_credit_lot_for_order


def toss_basic_auth_header() -> str:
    secret = settings.toss_secret_key.strip()
    token = base64.b64encode(f"{secret}:".encode()).decode()
    return f"Basic {token}"


def toss_checkout_url(
    *,
    order_id: str,
    order_name: str,
    amount_krw: int,
    web_checkout: bool = False,
) -> str:
    client_key = settings.toss_client_key.strip()
    base = "https://pay.toss.im/web/payment"
    if web_checkout or settings.payment_web_success_url:
        success = settings.payment_web_success_url or "http://127.0.0.1:8081/payment-success"
        fail = settings.payment_web_fail_url or "http://127.0.0.1:8081/payment-fail"
    else:
        success = "iljari://payment/success"
        fail = "iljari://payment/fail"
    query = {
        "orderId": order_id,
        "amount": str(amount_krw),
        "orderName": order_name,
        "successUrl": success,
        "failUrl": fail,
    }
    if client_key:
        query["clientKey"] = client_key
    return f"{base}?{urlencode(query)}"


def get_or_create_order(db: Session, body) -> PaymentOrderRow:
    row = db.get(PaymentOrderRow, body.order_id)
    if row is None:
        row = PaymentOrderRow(
            order_id=body.order_id,
            company_key=body.company_key,
            order_name=body.order_name,
            amount_krw=body.amount_krw,
            method=body.method,
            status="pending",
            mock=not bool(settings.toss_secret_key),
            credit_type=getattr(body, "credit_type", None),
            credit_count=getattr(body, "credit_count", None),
            credit_location_slots=getattr(body, "credit_location_slots", None),
        )
        db.add(row)
        db.flush()
    return row


def grant_pending_credit_for_order(db: Session, row: PaymentOrderRow) -> None:
    """confirmed 주문의 크레딧을 1회만 지갑에 지급 — 재시도·웹훅 중복 호출에도 안전."""
    if row.credit_granted or not row.credit_type or not row.company_key:
        return
    grant_credit_lot(
        db,
        row.company_key,
        row.credit_type,
        row.credit_count or 0,
        location_slots=row.credit_location_slots or 0,
        source_order_id=row.order_id,
    )
    row.credit_granted = True
    db.commit()


async def confirm_toss_payment(
    db: Session,
    *,
    payment_key: str,
    order_id: str,
    amount_krw: int,
    credit_type: str | None = None,
    credit_count: int | None = None,
    credit_location_slots: int | None = None,
) -> PaymentOrderRow:
    row = db.get(PaymentOrderRow, order_id)
    if row is None:
        row = PaymentOrderRow(
            order_id=order_id,
            amount_krw=amount_krw,
            status="pending",
            mock=False,
        )
        db.add(row)
        db.flush()

    # `/charge`를 거치지 않은 게이트웨이 대비 — order에 아직 구매 의도가 없으면 채움.
    if row.credit_type is None and credit_type is not None:
        row.credit_type = credit_type
        row.credit_count = credit_count
        row.credit_location_slots = credit_location_slots

    if row.status == "confirmed":
        grant_pending_credit_for_order(db, row)
        return row

    if not settings.toss_secret_key:
        row.status = "confirmed"
        row.payment_key = payment_key
        row.transaction_id = f"MOCK-CONFIRM-{order_id}"
        row.mock = True
        row.confirmed_at = datetime.utcnow()
        db.commit()
        grant_pending_credit_for_order(db, row)
        return row

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            "https://api.tosspayments.com/v1/payments/confirm",
            headers={
                "Authorization": toss_basic_auth_header(),
                "Content-Type": "application/json",
            },
            json={
                "paymentKey": payment_key,
                "orderId": order_id,
                "amount": amount_krw,
            },
        )

    if response.status_code >= 400:
        row.status = "failed"
        db.commit()
        raise ValueError("토스 결제 승인 실패")

    payload = response.json()
    row.status = "confirmed"
    row.payment_key = payment_key
    row.transaction_id = payload.get("paymentKey") or payload.get("transactionKey")
    row.mock = False
    row.confirmed_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    grant_pending_credit_for_order(db, row)
    return row


async def cancel_toss_payment(
    db: Session,
    *,
    order_id: str,
    cancel_reason: str,
) -> PaymentOrderRow:
    """결제취소(환불) — 확정된 주문만 취소 가능. 아직 쓰지 않은 크레딧 잔여분은 회수하고,
    이미 소비한 만큼은 되돌리지 않는다."""
    row = db.get(PaymentOrderRow, order_id)
    if row is None:
        raise ValueError("주문을 찾을 수 없습니다.")
    if row.status == "refunded":
        return row
    if row.status != "confirmed":
        raise ValueError("확정된 결제만 환불할 수 있습니다.")

    if row.mock or not settings.toss_secret_key:
        row.status = "refunded"
        row.refunded_at = datetime.utcnow()
        db.commit()
        revoke_credit_lot_for_order(db, order_id)
        return row

    payment_key = row.payment_key or row.transaction_id
    if not payment_key:
        raise ValueError("결제 키가 없어 환불할 수 없습니다.")

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            f"https://api.tosspayments.com/v1/payments/{payment_key}/cancel",
            headers={
                "Authorization": toss_basic_auth_header(),
                "Content-Type": "application/json",
            },
            json={"cancelReason": cancel_reason},
        )

    if response.status_code >= 400:
        raise ValueError("토스 결제 취소 실패")

    row.status = "refunded"
    row.refunded_at = datetime.utcnow()
    db.commit()
    db.refresh(row)
    revoke_credit_lot_for_order(db, order_id)
    return row
