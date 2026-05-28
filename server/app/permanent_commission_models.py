from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class PermanentEmployment(Base):
    __tablename__ = "permanent_employments"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    employment_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    application_id: Mapped[str] = mapped_column(String(64), index=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    company_name: Mapped[str] = mapped_column(String(200))
    seeker_email: Mapped[str] = mapped_column(String(200), index=True)
    seeker_name: Mapped[str] = mapped_column(String(120))
    monthly_salary_krw: Mapped[int] = mapped_column(Integer)
    hire_date: Mapped[datetime] = mapped_column(DateTime)
    active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class InsuranceVerificationLog(Base):
    __tablename__ = "insurance_verification_logs"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    log_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    employment_id: Mapped[str] = mapped_column(String(64), index=True)
    workplace_name: Mapped[str] = mapped_column(String(200))
    employer_company_name: Mapped[str] = mapped_column(String(200))
    company_name_matched: Mapped[bool] = mapped_column(Boolean, default=False)
    employed_confirmed: Mapped[bool] = mapped_column(Boolean, default=False)
    verified_at: Mapped[datetime] = mapped_column(DateTime)
    expires_at: Mapped[datetime] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(32))
    method: Mapped[str] = mapped_column(String(32), default="simple_auth")
    rejection_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    ci_hash: Mapped[str | None] = mapped_column(String(64), nullable=True)
    auth_provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    certificate_provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    cycle_number: Mapped[int] = mapped_column(Integer, default=0)
    simple_auth_session_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)


class MonthlyCommission(Base):
    __tablename__ = "monthly_commissions"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    commission_id: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    employment_id: Mapped[str] = mapped_column(String(64), index=True)
    period_start: Mapped[datetime] = mapped_column(DateTime)
    period_end: Mapped[datetime] = mapped_column(DateTime)
    monthly_salary_krw: Mapped[int] = mapped_column(Integer)
    commission_rate: Mapped[float] = mapped_column(Float, default=0.055)
    amount_krw: Mapped[int] = mapped_column(Integer, default=0)
    status: Mapped[str] = mapped_column(String(32))
    charged_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    skip_reason: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
