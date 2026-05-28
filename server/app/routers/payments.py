import httpx
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db

router = APIRouter(prefix="/v1/payments", tags=["payments"])


class ChargeRequest(BaseModel):
    order_id: str
    order_name: str
    amount_krw: int = Field(gt=0)
    method: str = "CARD"
    buyer_email: str | None = None
    buyer_name: str | None = None
    company_key: str | None = None


class ChargeResponse(BaseModel):
    success: bool
    transaction_id: str | None = None
    checkout_url: str | None = None
    payment_key: str | None = None
    mock: bool = False
    message: str | None = None


class ConfirmRequest(BaseModel):
    payment_key: str
    order_id: str
    amount_krw: int


@router.post("/charge", response_model=ChargeResponse)
async def charge_payment(body: ChargeRequest, db: Session = Depends(get_db)):
    del db  # reserved for payment ledger
    if not settings.toss_secret_key:
        return ChargeResponse(
            success=True,
            transaction_id=f"MOCK-{body.order_id}",
            mock=True,
        )

    checkout_url = (
        f"https://pay.toss.im/web/payment?orderId={body.order_id}"
        f"&amount={body.amount_krw}&orderName={body.order_name}"
        f"&successUrl=iljari://payment/success"
        f"&failUrl=iljari://payment/fail"
    )
    return ChargeResponse(
        success=True,
        payment_key=f"pending-{body.order_id}",
        checkout_url=checkout_url,
        mock=False,
    )


@router.post("/confirm", response_model=ChargeResponse)
async def confirm_payment(body: ConfirmRequest):
    if not settings.toss_secret_key:
        return ChargeResponse(
            success=True,
            transaction_id=f"MOCK-CONFIRM-{body.order_id}",
            mock=True,
        )

    async with httpx.AsyncClient(timeout=15.0) as client:
        response = await client.post(
            "https://api.tosspayments.com/v1/payments/confirm",
            headers={
                "Authorization": f"Basic {settings.toss_secret_key}",
                "Content-Type": "application/json",
            },
            json={
                "paymentKey": body.payment_key,
                "orderId": body.order_id,
                "amount": body.amount_krw,
            },
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=402, detail="토스 결제 승인 실패")

    payload = response.json()
    return ChargeResponse(
        success=True,
        transaction_id=payload.get("paymentKey") or payload.get("transactionKey"),
        mock=False,
    )
