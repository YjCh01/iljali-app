"""토스페이먼츠 결제 승인·원장."""

from __future__ import annotations

import base64
from datetime import datetime
from urllib.parse import urlencode

import httpx
from sqlalchemy.orm import Session

from app.config import settings
from app.job_sync_models import PaymentOrderRow


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
        )
        db.add(row)
        db.flush()
    return row


async def confirm_toss_payment(
    db: Session,
    *,
    payment_key: str,
    order_id: str,
    amount_krw: int,
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

    if row.status == "confirmed":
        return row

    if not settings.toss_secret_key:
        row.status = "confirmed"
        row.payment_key = payment_key
        row.transaction_id = f"MOCK-CONFIRM-{order_id}"
        row.mock = True
        row.confirmed_at = datetime.utcnow()
        db.commit()
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
    return row
