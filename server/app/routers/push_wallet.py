from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.push_wallet_schemas import (
    AddPackageCreditsRequest,
    ClaimSignupBonusResponse,
    CompanyBonusLedgerResponse,
    EmployerPushWalletResponse,
    EmployerPushWalletUpsert,
    SIGNUP_BONUS_GRANT,
)
from app.services.entitlement_service import normalize_brn
from app.services.push_wallet_service import (
    get_bonus_ledger,
    get_or_create_wallet,
    try_claim_signup_bonus,
    wallet_to_response,
)

router = APIRouter(prefix="/v1/wallet", tags=["wallet"])


@router.get("/{company_key}", response_model=EmployerPushWalletResponse)
def get_wallet(company_key: str, db: Session = Depends(get_db)):
    brn = normalize_brn(company_key)
    if len(brn) != 10:
        raise HTTPException(status_code=400, detail="사업자등록번호 10자리가 필요합니다.")
    wallet = get_or_create_wallet(db, brn)
    db.commit()
    return wallet_to_response(brn, wallet)


@router.put("/{company_key}", response_model=EmployerPushWalletResponse)
def upsert_wallet(
    company_key: str,
    body: EmployerPushWalletUpsert,
    db: Session = Depends(get_db),
):
    brn = normalize_brn(company_key)
    if len(brn) != 10:
        raise HTTPException(status_code=400, detail="사업자등록번호 10자리가 필요합니다.")
    wallet = get_or_create_wallet(db, brn)
    if body.package_credits is not None:
        wallet.package_credits = body.package_credits
    if body.signup_bonus_remaining is not None:
        wallet.signup_bonus_remaining = body.signup_bonus_remaining
    if body.location_slots_from_packages is not None:
        wallet.location_slots_from_packages = body.location_slots_from_packages
    if body.last_free_push_day_key is not None:
        wallet.last_free_push_day_key = body.last_free_push_day_key
    if body.signup_bonus_expires_at is not None:
        wallet.signup_bonus_expires_at = body.signup_bonus_expires_at
    db.commit()
    db.refresh(wallet)
    return wallet_to_response(brn, wallet)


@router.post("/{company_key}/credits", response_model=EmployerPushWalletResponse)
def add_package_credits(
    company_key: str,
    body: AddPackageCreditsRequest,
    db: Session = Depends(get_db),
):
    brn = normalize_brn(company_key)
    wallet = get_or_create_wallet(db, brn)
    slots = body.location_slots if body.location_slots is not None else body.count
    wallet.package_credits += body.count
    wallet.location_slots_from_packages += slots
    db.commit()
    db.refresh(wallet)
    return wallet_to_response(brn, wallet)


@router.get("/{company_key}/bonus", response_model=CompanyBonusLedgerResponse)
def get_bonus_ledger_status(company_key: str, db: Session = Depends(get_db)):
    brn = normalize_brn(company_key)
    ledger = get_bonus_ledger(db, brn)
    db.commit()
    return CompanyBonusLedgerResponse(
        company_key=brn,
        claimed=ledger.claimed,
        claimed_at=ledger.claimed_at,
        grant_count=SIGNUP_BONUS_GRANT,
    )


@router.post("/{company_key}/bonus/claim", response_model=ClaimSignupBonusResponse)
def claim_signup_bonus(company_key: str, db: Session = Depends(get_db)):
    brn = normalize_brn(company_key)
    if len(brn) != 10:
        raise HTTPException(status_code=400, detail="사업자등록번호 10자리가 필요합니다.")
    ok, granted = try_claim_signup_bonus(db, brn)
    if not ok:
        return ClaimSignupBonusResponse(
            company_key=brn,
            claimed=False,
            granted_pushes=0,
            message="이미 사업자번호로 보너스를 수령했습니다.",
        )
    return ClaimSignupBonusResponse(
        company_key=brn,
        claimed=True,
        granted_pushes=granted,
        message=f"신규 사업자 보너스 {granted}회가 지급되었습니다.",
    )
