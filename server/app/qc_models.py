"""QC·Admin Ops 영속 모델."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class QcMemberRow(Base):
    __tablename__ = "qc_members"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    email: Mapped[str] = mapped_column(String(200), unique=True, index=True)
    display_name: Mapped[str] = mapped_column(String(100), default="")
    member_type: Mapped[str] = mapped_column(String(16), default="seeker")
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    company_name: Mapped[str] = mapped_column(String(200), default="")
    is_suspended: Mapped[bool] = mapped_column(Boolean, default=False)
    is_permanently_banned: Mapped[bool] = mapped_column(Boolean, default=False)
    sanction_reason: Mapped[str] = mapped_column(Text, default="")
    sanction_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AdminAuditLogRow(Base):
    __tablename__ = "admin_audit_logs"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    action: Mapped[str] = mapped_column(String(64), index=True)
    target_type: Mapped[str] = mapped_column(String(32), default="")
    target_id: Mapped[str] = mapped_column(String(200), default="", index=True)
    detail_json: Mapped[str] = mapped_column(Text, default="{}")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class JobPostEntitlementRow(Base):
    __tablename__ = "job_post_entitlements"

    post_id: Mapped[str] = mapped_column(String(32), primary_key=True)
    recruitment_pin_active: Mapped[bool] = mapped_column(Boolean, default=False)
    shuttle_exposure_active: Mapped[bool] = mapped_column(Boolean, default=False)
    map_pin_tier: Mapped[str] = mapped_column(String(32), default="")
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
