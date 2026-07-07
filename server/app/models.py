from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

FLAGGED_KEYWORDS = (
    "인력공급",
    "파견",
    "아웃소싱",
    "인재파견",
    "용역",
    "도급",
    "헤드헌팅",
    "채용대행",
)


def industry_requires_review(industry: str | None) -> bool:
    if not industry:
        return False
    normalized = industry.replace(" ", "")
    return any(k.replace(" ", "") in normalized for k in FLAGGED_KEYWORDS)


class Company(Base):
    __tablename__ = "companies"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    company_key: Mapped[str] = mapped_column(String(10), unique=True, index=True)
    company_name: Mapped[str] = mapped_column(String(200))
    entity_type: Mapped[str] = mapped_column(String(32), default="corporation")
    industry_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    verification_status: Mapped[str] = mapped_column(String(32), default="pending")
    requires_admin_review: Mapped[bool] = mapped_column(Boolean, default=False)
    admin_review_approved: Mapped[bool] = mapped_column(Boolean, default=False)
    admin_review_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    policy_accepted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    is_suspended: Mapped[bool] = mapped_column(Boolean, default=False)
    partnership_tier: Mapped[str] = mapped_column(String(32), default="basic")
    monthly_subscription_active: Mapped[bool] = mapped_column(Boolean, default=False)
    subscription_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    certificate_image_ref: Mapped[str | None] = mapped_column(String(500), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ContactUsage(Base):
    __tablename__ = "contact_usage"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    month_key: Mapped[str] = mapped_column(String(7), index=True)
    attempt_count: Mapped[int] = mapped_column(Integer, default=0)


class ContactEvent(Base):
    __tablename__ = "contact_events"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    application_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    action: Mapped[str] = mapped_column(String(64))
    tier: Mapped[str] = mapped_column(String(32))
    allowed: Mapped[bool] = mapped_column(Boolean)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AbuseFlag(Base):
    __tablename__ = "abuse_flags"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    company_key: Mapped[str | None] = mapped_column(String(10), nullable=True, index=True)
    type: Mapped[str] = mapped_column(String(64))
    severity: Mapped[str] = mapped_column(String(16))
    message: Mapped[str] = mapped_column(Text)
    resolved: Mapped[bool] = mapped_column(Boolean, default=False)
    post_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    post_title: Mapped[str | None] = mapped_column(String(200), nullable=True)
    company_name: Mapped[str | None] = mapped_column(String(200), nullable=True)
    head_office_address: Mapped[str | None] = mapped_column(Text, nullable=True)
    workplace_address: Mapped[str | None] = mapped_column(Text, nullable=True)
    distance_meters: Mapped[int | None] = mapped_column(Integer, nullable=True)
    review_status: Mapped[str | None] = mapped_column(String(32), nullable=True)
    resolved_action: Mapped[str | None] = mapped_column(String(64), nullable=True)
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
