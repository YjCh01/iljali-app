from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class VerifyBusinessRequest(BaseModel):
    company_name: str
    business_registration_number: str = Field(min_length=10, max_length=12)
    representative_name: str = Field(default="", max_length=50)
    opening_date: str = Field(default="", max_length=8)
    entity_type: Literal["sole_proprietor", "corporation"] = "corporation"
    certificate_image_ref: str = ""


class VerifyBusinessResponse(BaseModel):
    company_key: str
    company_name: str
    status: str
    industry_name: str | None = None
    requires_admin_review: bool = False
    admin_review_reason: str | None = None
    trust_score: int = 100
    nts_api_matched: bool = False
    entity_type: str


class ContactEntitlementResponse(BaseModel):
    allowed: bool
    block_reason: str | None = None
    show_partnership_upsell: bool = False
    remaining_monthly_contacts: int | None = None
    per_contact_fee_krw: int | None = None


class ContactEventRequest(BaseModel):
    company_key: str
    application_id: str | None = None
    action: str
    tier: str = "basic"


class SubscribeRequest(BaseModel):
    company_key: str
    tier: Literal["starter", "growth", "enterprise"]
    amount_krw: int
    transaction_id: str | None = None


class SubscribeResponse(BaseModel):
    tier: str
    monthly_subscription_active: bool
    started_at: datetime


class AdminReviewRequest(BaseModel):
    approved: bool
    reason: str | None = None


class AbuseFlagResponse(BaseModel):
    id: int
    company_key: str | None
    type: str
    severity: str
    message: str
    created_at: datetime


class BusinessRecordResponse(BaseModel):
    company_key: str
    company_name: str
    industry_name: str | None
    verification_status: str
    requires_admin_review: bool
    admin_review_approved: bool
    is_suspended: bool
    partnership_tier: str
