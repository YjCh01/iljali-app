"""푸시·거점 지갑 및 BRN 보너스 원장 (map/PUSH_PACKAGE_PRICING.md)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

SIGNUP_BONUS_PUSHES = 5
SIGNUP_BONUS_VALID_DAYS = 90
PACKAGE_CREDIT_VALID_DAYS = 365


class EmployerPushWalletRow(Base):
    __tablename__ = "employer_push_wallets"

    company_key: Mapped[str] = mapped_column(String(10), primary_key=True)
    cash_balance_krw: Mapped[int] = mapped_column(Integer, default=0)
    package_credits: Mapped[int] = mapped_column(Integer, default=0)
    signup_bonus_remaining: Mapped[int] = mapped_column(Integer, default=0)
    location_slots_from_packages: Mapped[int] = mapped_column(Integer, default=0)
    last_free_push_day_key: Mapped[str | None] = mapped_column(String(10), nullable=True)
    signup_bonus_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )


class CompanyBonusLedgerRow(Base):
    __tablename__ = "company_bonus_ledger"

    company_key: Mapped[str] = mapped_column(String(10), primary_key=True)
    claimed: Mapped[bool] = mapped_column(Boolean, default=False)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
