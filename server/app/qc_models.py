"""QC·Admin Ops 영속 모델."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
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
    phone: Mapped[str] = mapped_column(String(32), default="", index=True)
    org_role: Mapped[str] = mapped_column(String(32), default="", index=True)
    branch_name: Mapped[str] = mapped_column(String(200), default="")
    department: Mapped[str] = mapped_column(String(100), default="")
    contact_person_name: Mapped[str] = mapped_column(String(100), default="")
    handler_code: Mapped[str] = mapped_column(String(32), default="")
    is_suspended: Mapped[bool] = mapped_column(Boolean, default=False)
    is_permanently_banned: Mapped[bool] = mapped_column(Boolean, default=False)
    sanction_tier: Mapped[str] = mapped_column(String(16), default="")
    warning_count: Mapped[int] = mapped_column(Integer, default=0)
    sanction_reason: Mapped[str] = mapped_column(Text, default="")
    sanction_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    sanction_restrictions_json: Mapped[str] = mapped_column(Text, default="{}")
    appeal_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    admin_review_required: Mapped[bool] = mapped_column(Boolean, default=False)
    password_hash: Mapped[str] = mapped_column(String(256), default="")
    phone_verified_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    seeker_profile_json: Mapped[str] = mapped_column(Text, default="{}")
    # 기업이 노쇼 처리할 때마다 누적 — 다른 기업도 지원자 조회 시 열람 가능.
    no_show_count: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MemberSocialLinkRow(Base):
    __tablename__ = "member_social_links"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    provider: Mapped[str] = mapped_column(String(16), index=True)
    provider_user_id: Mapped[str] = mapped_column(String(128), index=True)
    member_id: Mapped[str] = mapped_column(String(32), index=True)
    email: Mapped[str] = mapped_column(String(200), default="")
    display_name: Mapped[str] = mapped_column(String(100), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class CompanySanctionRow(Base):
    __tablename__ = "company_sanctions"

    company_key: Mapped[str] = mapped_column(String(10), primary_key=True)
    sanction_tier: Mapped[str] = mapped_column(String(16), default="")
    warning_count: Mapped[int] = mapped_column(Integer, default=0)
    is_suspended: Mapped[bool] = mapped_column(Boolean, default=False)
    sanction_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    restrictions_json: Mapped[str] = mapped_column(Text, default="{}")
    appeal_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    admin_review_required: Mapped[bool] = mapped_column(Boolean, default=False)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MemberSanctionHistoryRow(Base):
    __tablename__ = "member_sanction_history"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    email: Mapped[str] = mapped_column(String(200), index=True)
    company_key: Mapped[str] = mapped_column(String(10), default="", index=True)
    member_kind: Mapped[str] = mapped_column(String(16), default="seeker")
    tier: Mapped[str] = mapped_column(String(16))
    violation_code: Mapped[str] = mapped_column(String(64))
    reason: Mapped[str] = mapped_column(Text, default="")
    measures_json: Mapped[str] = mapped_column(Text, default="{}")
    source: Mapped[str] = mapped_column(String(32), default="admin")
    appeal_until: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
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


class ClosedGhostPinRow(Base):
    __tablename__ = "closed_ghost_pins"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    latitude: Mapped[float] = mapped_column()
    longitude: Mapped[float] = mapped_column()
    label: Mapped[str] = mapped_column(String(200), default="")
    source_post_id: Mapped[str] = mapped_column(String(64), default="", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class EventPinRow(Base):
    """어드민 이벤트핑 — 퀴즈·투표 등 구직자 참여 핀."""

    __tablename__ = "event_pins"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    latitude: Mapped[float] = mapped_column()
    longitude: Mapped[float] = mapped_column()
    title: Mapped[str] = mapped_column(String(200), default="")
    body: Mapped[str] = mapped_column(Text, default="")
    # info | quiz | vote
    kind: Mapped[str] = mapped_column(String(16), default="info", index=True)
    color_hex: Mapped[str] = mapped_column(String(16), default="#FF6F00")
    # JSON: {"options":["A","B"], "correct_index":0} etc.
    payload_json: Mapped[str] = mapped_column(Text, default="{}")
    active: Mapped[bool] = mapped_column(Boolean, default=True, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class ClosedGhostRouteRow(Base):
    __tablename__ = "closed_ghost_routes"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    label: Mapped[str] = mapped_column(String(200), default="")
    workplace_latitude: Mapped[float] = mapped_column()
    workplace_longitude: Mapped[float] = mapped_column()
    stops_json: Mapped[str] = mapped_column(Text, default="[]")
    ghost_pin_id: Mapped[str] = mapped_column(String(32), default="", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class AdminAnnouncementRow(Base):
    __tablename__ = "admin_announcements"

    id: Mapped[str] = mapped_column(String(32), primary_key=True)
    title: Mapped[str] = mapped_column(String(200))
    body: Mapped[str] = mapped_column(Text)
    audience: Mapped[str] = mapped_column(String(16), default="all", index=True)
    push_requested: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
