import hashlib
import hmac
import json

from fastapi import APIRouter, Header, HTTPException, Request

from app.config import settings

router = APIRouter(prefix="/v1/payments", tags=["payments-webhook"])


@router.post("/webhook/toss")
async def toss_webhook(
    request: Request,
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

    return {
        "received": True,
        "event_type": event_type,
        "order_id": order_id,
        "mock": not settings.toss_webhook_secret,
    }
