import hashlib
import hmac
import json
from datetime import datetime

from fastapi import APIRouter, Depends, Header, HTTPException, Request
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.job_sync_models import PaymentOrderRow
from app.services.payment_service import grant_pending_credit_for_order

router = APIRouter(prefix="/v1/payments", tags=["payments-webhook"])


@router.post("/webhook/toss")
async def toss_webhook(
    request: Request,
    db: Session = Depends(get_db),
    toss_signature: str | None = Header(default=None, alias="Toss-Signature"),
):
    body = await request.body()

    if settings.toss_webhook_secret:
        expected = hmac.new(
            settings.toss_webhook_secret.encode(),
            body,
            hashlib.sha256,
        ).hexdigest()
        if not toss_signature or not hmac.compare_digest(expected, toss_signature):
            raise HTTPException(status_code=401, detail="Invalid webhook signature")

    try:
        payload = json.loads(body.decode())
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=400, detail="Invalid JSON") from exc

    event_type = payload.get("eventType") or payload.get("status") or "unknown"
    order_id = payload.get("orderId") or payload.get("data", {}).get("orderId")
    payment_key = payload.get("paymentKey") or payload.get("data", {}).get("paymentKey")

    if order_id:
        row = db.get(PaymentOrderRow, order_id)
        if row is None:
            row = PaymentOrderRow(
                order_id=order_id,
                amount_krw=int(payload.get("amount") or payload.get("totalAmount") or 0),
                status="pending",
            )
            db.add(row)
        if event_type in ("PAYMENT_STATUS_CHANGED", "DONE", "done", "confirmed"):
            row.status = "confirmed"
            row.payment_key = payment_key or row.payment_key
            row.transaction_id = payment_key or row.transaction_id
            row.confirmed_at = datetime.utcnow()
            db.commit()
            grant_pending_credit_for_order(db, row)
        elif event_type in ("CANCELED", "canceled", "failed"):
            row.status = "failed"
            db.commit()
        else:
            db.commit()

    return {
        "received": True,
        "event_type": event_type,
        "order_id": order_id,
        "mock": not settings.toss_webhook_secret,
    }
