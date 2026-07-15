"""푸시·거점 지갑 및 BRN 보너스 원장 (map/PUSH_PACKAGE_PRICING.md)."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base

# PRD §4.1 (PRODUCT_REQUIREMENTS.md) 기준 — 가입 보너스 2회/30일, 인증 보너스 5회/30일.
SIGNUP_BONUS_PUSHES = 2
SIGNUP_BONUS_VALID_DAYS = 30
VERIFICATION_BONUS_PUSHES = 5
VERIFICATION_BONUS_VALID_DAYS = 30
PACKAGE_CREDIT_VALID_DAYS = 180

CREDIT_TYPE_PACKAGE = "package"
CREDIT_TYPE_PUSH_TICKET = "push_ticket"
CREDIT_TYPE_EXPOSURE_BUNDLE = "exposure_bundle"
CREDIT_TYPES = (CREDIT_TYPE_PACKAGE, CREDIT_TYPE_PUSH_TICKET, CREDIT_TYPE_EXPOSURE_BUNDLE)


class EmployerPushWalletRow(Base):
    __tablename__ = "employer_push_wallets"

    company_key: Mapped[str] = mapped_column(String(10), primary_key=True)
    cash_balance_krw: Mapped[int] = mapped_column(Integer, default=0)
    package_credits: Mapped[int] = mapped_column(Integer, default=0)
    push_ticket_credits: Mapped[int] = mapped_column(Integer, default=0)
    exposure_push_bundle_credits: Mapped[int] = mapped_column(Integer, default=0)
    signup_bonus_remaining: Mapped[int] = mapped_column(Integer, default=0)
    location_slots_from_packages: Mapped[int] = mapped_column(Integer, default=0)
    last_free_push_day_key: Mapped[str | None] = mapped_column(String(10), nullable=True)
    signup_bonus_expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow
    )


class PushWalletCreditLotRow(Base):
    """구매/지급 크레딧 배치 — 만료(180일) 추적 전용. 지갑 flat 컬럼이 잔액 원장이고,
    이 테이블은 언제 얼마가 만료되어 flat 컬럼에서 빠져야 하는지만 기록한다."""

    __tablename__ = "push_wallet_credit_lots"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    company_key: Mapped[str] = mapped_column(String(10), index=True)
    credit_type: Mapped[str] = mapped_column(String(32))
    count: Mapped[int] = mapped_column(Integer)
    # 소비(consume) 시 FIFO로 차감되는 잔여분 — 만료 스윕은 이 값만 flat 컬럼에서 뺀다.
    remaining: Mapped[int] = mapped_column(Integer)
    granted_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    expires_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    # 구매 건 order_id — 동일 주문의 중복 지급(idempotency) 방지. 관리자 수동 지급 등
    # 주문이 없는 경우는 NULL(다건 허용).
    source_order_id: Mapped[str | None] = mapped_column(
        String(128), nullable=True, unique=True, index=True
    )
    swept: Mapped[bool] = mapped_column(Boolean, default=False)


class CompanyBonusLedgerRow(Base):
    __tablename__ = "company_bonus_ledger"

    company_key: Mapped[str] = mapped_column(String(10), primary_key=True)
    claimed: Mapped[bool] = mapped_column(Boolean, default=False)
    claimed_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    verification_bonus_claimed: Mapped[bool] = mapped_column(Boolean, default=False)
    verification_bonus_claimed_at: Mapped[datetime | None] = mapped_column(
        DateTime, nullable=True
    )
