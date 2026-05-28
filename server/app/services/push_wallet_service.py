from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.push_wallet_models import (
    SIGNUP_BONUS_PUSHES,
    SIGNUP_BONUS_VALID_DAYS,
    CompanyBonusLedgerRow,
    EmployerPushWalletRow,
)
from app.push_wallet_schemas import EmployerPushWalletResponse
from app.services.entitlement_service import normalize_brn

BASE_LOCATION_SLOTS = 1
DAILY_FREE_PUSH = 1


def _today_key(dt: datetime | None = None) -> str:
    d = dt or datetime.utcnow()
    return f"{d.year}-{d.month:02d}-{d.day:02d}"


def _effective_signup_bonus(wallet: EmployerPushWalletRow) -> int:
    if wallet.signup_bonus_remaining <= 0:
        return 0
    expires = wallet.signup_bonus_expires_at
    if expires is not None and datetime.utcnow() > expires:
        return 0
    return wallet.signup_bonus_remaining


def _daily_free_remaining(wallet: EmployerPushWalletRow) -> int:
    if wallet.last_free_push_day_key == _today_key():
        return 0
    return DAILY_FREE_PUSH


def wallet_to_response(
    company_key: str, wallet: EmployerPushWalletRow
) -> EmployerPushWalletResponse:
    bonus = _effective_signup_bonus(wallet)
    daily = _daily_free_remaining(wallet)
    available = wallet.package_credits + bonus + daily
    total_slots = BASE_LOCATION_SLOTS + wallet.location_slots_from_packages
    return EmployerPushWalletResponse(
        company_key=company_key,
        package_credits=wallet.package_credits,
        signup_bonus_remaining=wallet.signup_bonus_remaining,
        location_slots_from_packages=wallet.location_slots_from_packages,
        last_free_push_day_key=wallet.last_free_push_day_key,
        signup_bonus_expires_at=wallet.signup_bonus_expires_at,
        total_location_slots=total_slots,
        available_push_credits=available,
    )


def get_or_create_wallet(db: Session, company_key: str) -> EmployerPushWalletRow:
    brn = normalize_brn(company_key)
    row = (
        db.query(EmployerPushWalletRow)
        .filter(EmployerPushWalletRow.company_key == brn)
        .first()
    )
    if row is None:
        row = EmployerPushWalletRow(company_key=brn)
        db.add(row)
        db.flush()
    return row


def get_bonus_ledger(db: Session, company_key: str) -> CompanyBonusLedgerRow:
    brn = normalize_brn(company_key)
    row = (
        db.query(CompanyBonusLedgerRow)
        .filter(CompanyBonusLedgerRow.company_key == brn)
        .first()
    )
    if row is None:
        row = CompanyBonusLedgerRow(company_key=brn, claimed=False)
        db.add(row)
        db.flush()
    return row


def try_claim_signup_bonus(db: Session, company_key: str) -> tuple[bool, int]:
    """BRN당 1회 — 성공 시 보너스 5회 지급."""
    ledger = get_bonus_ledger(db, company_key)
    if ledger.claimed:
        return False, 0

    brn = normalize_brn(company_key)
    ledger.claimed = True
    ledger.claimed_at = datetime.utcnow()

    wallet = get_or_create_wallet(db, brn)
    wallet.signup_bonus_remaining = SIGNUP_BONUS_PUSHES
    wallet.signup_bonus_expires_at = datetime.utcnow() + timedelta(
        days=SIGNUP_BONUS_VALID_DAYS
    )
    wallet.location_slots_from_packages += SIGNUP_BONUS_PUSHES
    db.commit()
    return True, SIGNUP_BONUS_PUSHES
