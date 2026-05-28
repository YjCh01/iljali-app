from datetime import datetime

from pydantic import BaseModel, Field

SIGNUP_BONUS_GRANT = 5


class EmployerPushWalletResponse(BaseModel):
    company_key: str
    package_credits: int = 0
    signup_bonus_remaining: int = 0
    location_slots_from_packages: int = 0
    last_free_push_day_key: str | None = None
    signup_bonus_expires_at: datetime | None = None
    total_location_slots: int
    available_push_credits: int


class EmployerPushWalletUpsert(BaseModel):
    package_credits: int | None = None
    signup_bonus_remaining: int | None = None
    location_slots_from_packages: int | None = None
    last_free_push_day_key: str | None = None
    signup_bonus_expires_at: datetime | None = None


class AddPackageCreditsRequest(BaseModel):
    count: int = Field(ge=1, le=500)
    location_slots: int | None = Field(default=None, ge=0)


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
