from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field

from app.push_wallet_models import CREDIT_TYPE_PACKAGE

SIGNUP_BONUS_GRANT = 2


class EmployerPushWalletResponse(BaseModel):
    company_key: str
    package_credits: int = 0
    push_ticket_credits: int = 0
    exposure_push_bundle_credits: int = 0
    cash_balance_krw: int = 0
    signup_bonus_remaining: int = 0
    location_slots_from_packages: int = 0
    last_free_push_day_key: str | None = None
    signup_bonus_expires_at: datetime | None = None
    total_location_slots: int
    available_push_credits: int


class EmployerPushWalletUpsert(BaseModel):
    package_credits: int | None = None
    push_ticket_credits: int | None = None
    cash_balance_krw: int | None = None
    signup_bonus_remaining: int | None = None
    location_slots_from_packages: int | None = None
    last_free_push_day_key: str | None = None
    signup_bonus_expires_at: datetime | None = None


class AddPackageCreditsRequest(BaseModel):
    count: int = Field(ge=1, le=500)
    location_slots: int | None = Field(default=None, ge=0)
    credit_type: Literal["package", "push_ticket", "exposure_bundle"] = (
        CREDIT_TYPE_PACKAGE
    )
    # 관리자 수동 지급 등 주문이 없는 지급은 생략 가능. 구매 플로우에서는
    # 결제 confirm이 이 값을 채워 넣어 재시도 시 중복 지급을 막는다.
    order_id: str | None = None


class ConsumeCreditRequest(BaseModel):
    credit_type: Literal["package", "push_ticket", "exposure_bundle"] = (
        CREDIT_TYPE_PACKAGE
    )
    count: int = Field(default=1, ge=1, le=500)


class CompanyBonusLedgerResponse(BaseModel):
    company_key: str
    claimed: bool
    claimed_at: datetime | None = None
    grant_count: int = SIGNUP_BONUS_GRANT


class ClaimSignupBonusResponse(BaseModel):
    company_key: str
    claimed: bool
    granted_pushes: int = 0
    message: str | None = None


class WalletCreditLotResponse(BaseModel):
    credit_type: str
    remaining: int
    granted_at: datetime
    expires_at: datetime | None = None
    source_order_id: str | None = None


class WalletCreditLotListResponse(BaseModel):
    company_key: str
    lots: list[WalletCreditLotResponse]
