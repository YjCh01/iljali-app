from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class InsuranceAuthSession(Base):
    """간편인증 세션 — Barocert/PortOne/Mock."""

    __tablename__ = "insurance_auth_sessions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    session_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    employment_id: Mapped[str] = mapped_column(String(64), index=True)
    seeker_email: Mapped[str] = mapped_column(String(200), index=True)
    auth_provider: Mapped[str] = mapped_column(String(32))  # naver|kakao|toss|pass
    auth_backend: Mapped[str] = mapped_column(String(32), default="mock")
    status: Mapped[str] = mapped_column(String(32), default="pending")
    ci_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    ci_encrypted: Mapped[str | None] = mapped_column(Text, nullable=True)
    external_tx_id: Mapped[str | None] = mapped_column(String(128), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    completed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class MonthlyReemployment(Base):
    """30일 주기 재직 확인 이력."""

    __tablename__ = "monthly_reemployments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    reemployment_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    employment_id: Mapped[str] = mapped_column(String(64), index=True)
    cycle_number: Mapped[int] = mapped_column(Integer, default=0)
    period_start: Mapped[datetime] = mapped_column(DateTime)
    period_end: Mapped[datetime] = mapped_column(DateTime)
    verification_log_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    status: Mapped[str] = mapped_column(String(32))  # verified|failed|skipped|pending
    failure_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
