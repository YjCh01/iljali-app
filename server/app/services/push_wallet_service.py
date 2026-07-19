from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.push_wallet_models import (
    CREDIT_TYPE_EXPOSURE_BUNDLE,
    CREDIT_TYPE_PACKAGE,
    CREDIT_TYPE_PUSH_TICKET,
    PACKAGE_CREDIT_VALID_DAYS,
    SIGNUP_BONUS_PUSHES,
    SIGNUP_BONUS_VALID_DAYS,
    VERIFICATION_BONUS_PUSHES,
    VERIFICATION_BONUS_VALID_DAYS,
    CompanyBonusLedgerRow,
    EmployerPushWalletRow,
    PushWalletCreditLotRow,
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


def _apply_credit_delta(
    wallet: EmployerPushWalletRow, credit_type: str, delta: int
) -> None:
    """delta만큼 flat 컬럼에 가감 (delta<0 이면 차감). package는 노출 슬롯도 연동."""
    if credit_type == CREDIT_TYPE_PACKAGE:
        wallet.package_credits = max(0, wallet.package_credits + delta)
        wallet.location_slots_from_packages = max(
            0, wallet.location_slots_from_packages + delta
        )
    elif credit_type == CREDIT_TYPE_PUSH_TICKET:
        wallet.push_ticket_credits = max(0, wallet.push_ticket_credits + delta)
    elif credit_type == CREDIT_TYPE_EXPOSURE_BUNDLE:
        wallet.exposure_push_bundle_credits = max(
            0, wallet.exposure_push_bundle_credits + delta
        )
    else:
        raise ValueError(f"알 수 없는 credit_type: {credit_type}")


def _credit_balance(wallet: EmployerPushWalletRow, credit_type: str) -> int:
    if credit_type == CREDIT_TYPE_PACKAGE:
        return wallet.package_credits
    if credit_type == CREDIT_TYPE_PUSH_TICKET:
        return wallet.push_ticket_credits
    if credit_type == CREDIT_TYPE_EXPOSURE_BUNDLE:
        return wallet.exposure_push_bundle_credits
    raise ValueError(f"알 수 없는 credit_type: {credit_type}")


def _sweep_expired_lots(db: Session, wallet: EmployerPushWalletRow) -> None:
    """만료된(180일) 크레딧 배치의 미소비 잔여분(remaining)만 flat 잔액에서 차감."""
    now = datetime.utcnow()
    lots = (
        db.query(PushWalletCreditLotRow)
        .filter(
            PushWalletCreditLotRow.company_key == wallet.company_key,
            PushWalletCreditLotRow.swept.is_(False),
            PushWalletCreditLotRow.expires_at.is_not(None),
            PushWalletCreditLotRow.expires_at <= now,
        )
        .all()
    )
    if not lots:
        return
    for lot in lots:
        if lot.remaining > 0:
            _apply_credit_delta(wallet, lot.credit_type, -lot.remaining)
            lot.remaining = 0
        lot.swept = True
    db.commit()
    db.refresh(wallet)


def consume_credit(db: Session, company_key: str, credit_type: str, count: int) -> bool:
    """크레딧 소비 — FIFO로 오래된(만료 임박) 배치부터 차감, 잔액 부족 시 아무 것도
    바꾸지 않고 False. lot에 없는 잔액(마이그레이션 이전 레거시분)은 마지막에 소비."""
    if count <= 0:
        return True
    brn = normalize_brn(company_key)
    wallet = get_or_create_wallet(db, brn)
    _sweep_expired_lots(db, wallet)

    if _credit_balance(wallet, credit_type) < count:
        return False

    now = datetime.utcnow()
    lots = (
        db.query(PushWalletCreditLotRow)
        .filter(
            PushWalletCreditLotRow.company_key == brn,
            PushWalletCreditLotRow.credit_type == credit_type,
            PushWalletCreditLotRow.swept.is_(False),
            PushWalletCreditLotRow.remaining > 0,
        )
        .order_by(PushWalletCreditLotRow.granted_at.asc())
        .all()
    )
    remaining_to_consume = count
    for lot in lots:
        if remaining_to_consume <= 0:
            break
        if lot.expires_at is not None and lot.expires_at <= now:
            continue
        take = min(lot.remaining, remaining_to_consume)
        lot.remaining -= take
        remaining_to_consume -= take

    _apply_credit_delta(wallet, credit_type, -count)
    db.commit()
    return True


def revoke_credit_lot_for_order(db: Session, order_id: str) -> None:
    """환불된 주문의 크레딧 배치 중 아직 쓰지 않은 잔여분만 회수한다(이미 소비한 만큼은
    되돌리지 않음). 배치가 없거나 이미 회수됐으면 아무 것도 하지 않는다."""
    lot = (
        db.query(PushWalletCreditLotRow)
        .filter(PushWalletCreditLotRow.source_order_id == order_id)
        .first()
    )
    if lot is None or lot.swept or lot.remaining <= 0:
        return
    wallet = get_or_create_wallet(db, lot.company_key)
    _apply_credit_delta(wallet, lot.credit_type, -lot.remaining)
    lot.remaining = 0
    lot.swept = True
    db.commit()


def grant_credit_lot(
    db: Session,
    company_key: str,
    credit_type: str,
    count: int,
    *,
    location_slots: int = 0,
    valid_days: int | None = PACKAGE_CREDIT_VALID_DAYS,
    source_order_id: str | None = None,
) -> EmployerPushWalletRow:
    """구매/지급 크레딧을 지갑에 반영. `source_order_id`가 이미 지급 처리된 주문이면
    아무것도 하지 않고 현재 지갑을 그대로 반환 — 재시도로 인한 중복 지급 방지."""
    brn = normalize_brn(company_key)
    if source_order_id:
        existing = (
            db.query(PushWalletCreditLotRow)
            .filter(PushWalletCreditLotRow.source_order_id == source_order_id)
            .first()
        )
        if existing is not None:
            return get_or_create_wallet(db, brn)

    wallet = get_or_create_wallet(db, brn)
    if count > 0:
        if credit_type == CREDIT_TYPE_PACKAGE:
            wallet.package_credits += count
            wallet.location_slots_from_packages += location_slots or count
        elif credit_type in (CREDIT_TYPE_PUSH_TICKET, CREDIT_TYPE_EXPOSURE_BUNDLE):
            _apply_credit_delta(wallet, credit_type, count)
        else:
            raise ValueError(f"알 수 없는 credit_type: {credit_type}")

        expires_at = (
            datetime.utcnow() + timedelta(days=valid_days) if valid_days else None
        )
        db.add(
            PushWalletCreditLotRow(
                company_key=brn,
                credit_type=credit_type,
                count=count,
                remaining=count,
                expires_at=expires_at,
                source_order_id=source_order_id,
            )
        )
    db.commit()
    db.refresh(wallet)
    return wallet


def wallet_to_response(
    company_key: str, wallet: EmployerPushWalletRow, db: Session
) -> EmployerPushWalletResponse:
    _sweep_expired_lots(db, wallet)
    bonus = _effective_signup_bonus(wallet)
    daily = _daily_free_remaining(wallet)
    available = wallet.package_credits + bonus + daily
    total_slots = BASE_LOCATION_SLOTS + wallet.location_slots_from_packages
    return EmployerPushWalletResponse(
        company_key=company_key,
        package_credits=wallet.package_credits,
        push_ticket_credits=wallet.push_ticket_credits,
        exposure_push_bundle_credits=wallet.exposure_push_bundle_credits,
        cash_balance_krw=wallet.cash_balance_krw,
        signup_bonus_remaining=wallet.signup_bonus_remaining,
        location_slots_from_packages=wallet.location_slots_from_packages,
        last_free_push_day_key=wallet.last_free_push_day_key,
        signup_bonus_expires_at=wallet.signup_bonus_expires_at,
        total_location_slots=total_slots,
        available_push_credits=available,
    )


def list_active_lots(db: Session, company_key: str) -> list[PushWalletCreditLotRow]:
    """만료 스윕 후 남아있는(remaining > 0) 크레딧 배치를 만료일 임박 순으로 반환."""
    wallet = get_or_create_wallet(db, company_key)
    _sweep_expired_lots(db, wallet)
    return (
        db.query(PushWalletCreditLotRow)
        .filter(
            PushWalletCreditLotRow.company_key == wallet.company_key,
            PushWalletCreditLotRow.remaining > 0,
        )
        .order_by(PushWalletCreditLotRow.expires_at.asc().nullslast())
        .all()
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


def try_claim_verification_bonus(db: Session, company_key: str) -> tuple[bool, int]:
    """BRN당 1회 — 사업자 인증(verified) 완료 시 알림핀 5회/30일 지급 (PRD §4.1)."""
    ledger = get_bonus_ledger(db, company_key)
    if ledger.verification_bonus_claimed:
        return False, 0

    brn = normalize_brn(company_key)
    ledger.verification_bonus_claimed = True
    ledger.verification_bonus_claimed_at = datetime.utcnow()
    db.commit()

    grant_credit_lot(
        db,
        brn,
        CREDIT_TYPE_PACKAGE,
        VERIFICATION_BONUS_PUSHES,
        location_slots=VERIFICATION_BONUS_PUSHES,
        valid_days=VERIFICATION_BONUS_VALID_DAYS,
    )
    return True, VERIFICATION_BONUS_PUSHES
