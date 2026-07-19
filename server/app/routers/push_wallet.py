from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps.admin_auth import require_admin_api_key
from app.routers.job_board import _assert_employer_company, _resolve_bearer
from app.push_wallet_schemas import (
    AddPackageCreditsRequest,
    ClaimSignupBonusResponse,
    CompanyBonusLedgerResponse,
    ConsumeCreditRequest,
    EmployerPushWalletResponse,
    EmployerPushWalletUpsert,
    SIGNUP_BONUS_GRANT,
    WalletCreditLotListResponse,
    WalletCreditLotResponse,
)
from app.services.entitlement_service import normalize_brn
from app.services.push_wallet_service import (
    consume_credit,
    get_bonus_ledger,
    get_or_create_wallet,
    grant_credit_lot,
    list_active_lots,
    try_claim_signup_bonus,
    wallet_to_response,
)

router = APIRouter(prefix="/v1/wallet", tags=["wallet"])


@router.get("/{company_key}", response_model=EmployerPushWalletResponse)
def get_wallet(
    company_key: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    _assert_employer_company(payload, company_key)
    brn = normalize_brn(company_key)
    if len(brn) != 10:
        raise HTTPException(status_code=400, detail="사업자등록번호 10자리가 필요합니다.")
    wallet = get_or_create_wallet(db, brn)
    db.commit()
    return wallet_to_response(brn, wallet, db)


@router.put("/{company_key}", response_model=EmployerPushWalletResponse)
def upsert_wallet(
    company_key: str,
    body: EmployerPushWalletUpsert,
    db: Session = Depends(get_db),
    _admin: str = Depends(require_admin_api_key),
):
    brn = normalize_brn(company_key)
    if len(brn) != 10:
        raise HTTPException(status_code=400, detail="사업자등록번호 10자리가 필요합니다.")
    wallet = get_or_create_wallet(db, brn)
    if body.package_credits is not None:
        wallet.package_credits = body.package_credits
    if body.cash_balance_krw is not None:
        wallet.cash_balance_krw = body.cash_balance_krw
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
    return wallet_to_response(brn, wallet, db)


@router.post("/{company_key}/credits", response_model=EmployerPushWalletResponse)
def add_package_credits(
    company_key: str,
    body: AddPackageCreditsRequest,
    db: Session = Depends(get_db),
    _admin: str = Depends(require_admin_api_key),
):
    """관리자 수동 지급 등 구매 플로우 밖에서 크레딧을 넣을 때 사용. 실제 구매는
    `/v1/payments/confirm`이 confirmed 전환 시 자동으로 크레딧을 지급하므로 이 경로를
    타지 않는다."""
    brn = normalize_brn(company_key)
    wallet = grant_credit_lot(
        db,
        brn,
        body.credit_type,
        body.count,
        location_slots=body.location_slots or 0,
        source_order_id=body.order_id,
    )
    return wallet_to_response(brn, wallet, db)


@router.post("/{company_key}/consume", response_model=EmployerPushWalletResponse)
def consume_wallet_credit(
    company_key: str,
    body: ConsumeCreditRequest,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """알림핀·PUSH 이용권 등 실사용(소비) — 잔액 부족 시 402."""
    payload = _resolve_bearer(authorization)
    _assert_employer_company(payload, company_key)
    brn = normalize_brn(company_key)
    ok = consume_credit(db, brn, body.credit_type, body.count)
    if not ok:
        raise HTTPException(status_code=402, detail="크레딧 잔액이 부족합니다.")
    wallet = get_or_create_wallet(db, brn)
    return wallet_to_response(brn, wallet, db)


@router.get("/{company_key}/lots", response_model=WalletCreditLotListResponse)
def list_wallet_lots(
    company_key: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    _assert_employer_company(payload, company_key)
    brn = normalize_brn(company_key)
    lots = list_active_lots(db, brn)
    return WalletCreditLotListResponse(
        company_key=brn,
        lots=[
            WalletCreditLotResponse(
                credit_type=lot.credit_type,
                remaining=lot.remaining,
                granted_at=lot.granted_at,
                expires_at=lot.expires_at,
                source_order_id=lot.source_order_id,
            )
            for lot in lots
        ],
    )


@router.get("/{company_key}/bonus", response_model=CompanyBonusLedgerResponse)
def get_bonus_ledger_status(
    company_key: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    _assert_employer_company(payload, company_key)
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
def claim_signup_bonus(
    company_key: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    _assert_employer_company(payload, company_key)
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
