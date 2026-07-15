from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.job_sync_models import PaymentOrderRow
from app.services.payment_service import (
    confirm_toss_payment,
    get_or_create_order,
    toss_checkout_url,
)

router = APIRouter(prefix="/v1/payments", tags=["payments"])


class ChargeRequest(BaseModel):
    order_id: str
    order_name: str
    amount_krw: int = Field(gt=0)
    method: str = "CARD"
    buyer_email: str | None = None
    buyer_name: str | None = None
    company_key: str | None = None
    web_checkout: bool = False
    # 구매 의도 — confirm 시 자동 지급할 지갑 크레딧. 알림핀/PUSH 이용권 등
    # 크레딧성 상품 결제에서만 채워짐.
    credit_type: str | None = None
    credit_count: int | None = None
    credit_location_slots: int | None = None


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
    # `/charge`를 거치지 않은 게이트웨이(클라이언트 키 직결 checkout)를 대비한 보강 —
    # 이미 order에 credit_type이 있으면 무시되고 없을 때만 채워짐.
    credit_type: str | None = None
    credit_count: int | None = None
    credit_location_slots: int | None = None


@router.post("/charge", response_model=ChargeResponse)
async def charge_payment(body: ChargeRequest, db: Session = Depends(get_db)):
    row = get_or_create_order(db, body)
    db.commit()

    if not settings.toss_secret_key:
        row.status = "confirmed"
        row.transaction_id = f"MOCK-{body.order_id}"
        row.mock = True
        db.commit()
        return ChargeResponse(
            success=True,
            transaction_id=row.transaction_id,
            mock=True,
            message="TOSS_SECRET_KEY 미설정 — mock 결제",
        )

    checkout_url = toss_checkout_url(
        order_id=body.order_id,
        order_name=body.order_name,
        amount_krw=body.amount_krw,
        web_checkout=body.web_checkout,
    )
    return ChargeResponse(
        success=True,
        payment_key=f"pending-{body.order_id}",
        checkout_url=checkout_url,
        mock=False,
    )


@router.post("/confirm", response_model=ChargeResponse)
async def confirm_payment(body: ConfirmRequest, db: Session = Depends(get_db)):
    try:
        row = await confirm_toss_payment(
            db,
            payment_key=body.payment_key,
            order_id=body.order_id,
            amount_krw=body.amount_krw,
            credit_type=body.credit_type,
            credit_count=body.credit_count,
            credit_location_slots=body.credit_location_slots,
        )
    except ValueError as exc:
        raise HTTPException(status_code=402, detail=str(exc)) from exc

    return ChargeResponse(
        success=True,
        transaction_id=row.transaction_id,
        mock=row.mock,
    )


@router.get("/orders/{order_id}")
def get_payment_order(order_id: str, db: Session = Depends(get_db)):
    row = db.get(PaymentOrderRow, order_id)
    if row is None:
        raise HTTPException(status_code=404, detail="주문을 찾을 수 없습니다.")
    return {
        "order_id": row.order_id,
        "status": row.status,
        "amount_krw": row.amount_krw,
        "transaction_id": row.transaction_id,
        "mock": row.mock,
    }
