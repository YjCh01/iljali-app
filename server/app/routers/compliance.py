from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AbuseFlag, Company, ContactEvent, industry_requires_review
from app.schemas import (
    ContactEntitlementResponse,
    ContactEventRequest,
    VerifyBusinessRequest,
    VerifyBusinessResponse,
)
from app.services.entitlement_service import (
    evaluate_contact,
    get_or_create_company,
    increment_contact,
    normalize_brn,
)
from app.services.nts_service import NtsService

router = APIRouter(prefix="/v1/compliance", tags=["compliance"])
nts = NtsService()


@router.post("/business/verify", response_model=VerifyBusinessResponse)
async def verify_business(body: VerifyBusinessRequest, db: Session = Depends(get_db)):
    brn = normalize_brn(body.business_registration_number)
    if len(brn) != 10:
        raise HTTPException(status_code=400, detail="사업자등록번호 10자리가 필요합니다.")

    lookup = await nts.verify_business(
        brn,
        body.company_name,
        representative_name=body.representative_name,
        opening_date=body.opening_date,
    )
    if not lookup.valid:
        raise HTTPException(
            status_code=422,
            detail=lookup.failure_message
            or "국세청 조회 결과 유효하지 않은 사업자입니다.",
        )

    flagged = industry_requires_review(lookup.industry_name)
    status = "adminReviewRequired" if flagged else "verified"
    reason = (
        f"업종「{lookup.industry_name}」— 인력공급·아웃소싱 의심, Enterprise 가입·관리자 승인 필요"
        if flagged
        else None
    )

    company = get_or_create_company(db, brn, body.company_name, body.entity_type)
    company.industry_name = lookup.industry_name
    company.verification_status = status
    company.requires_admin_review = flagged
    company.admin_review_approved = False if flagged else company.admin_review_approved
    company.admin_review_reason = reason
    company.certificate_image_ref = body.certificate_image_ref
    company.policy_accepted_at = company.policy_accepted_at or __import__("datetime").datetime.utcnow()
    db.commit()
    db.refresh(company)

    if flagged:
        db.add(
            AbuseFlag(
                company_key=brn,
                type="industry_flag",
                severity="high",
                message=reason or "업종 플래그",
            )
        )
        db.commit()

    return VerifyBusinessResponse(
        company_key=brn,
        company_name=company.company_name,
        status=status,
        industry_name=lookup.industry_name,
        requires_admin_review=flagged,
        admin_review_reason=reason,
        trust_score=40 if flagged else 100,
        nts_api_matched=lookup.api_source != "mock_nts",
        entity_type=body.entity_type,
    )


@router.get("/business/{company_key}", response_model=VerifyBusinessResponse)
def get_business(company_key: str, db: Session = Depends(get_db)):
    brn = normalize_brn(company_key)
    company = db.query(Company).filter(Company.company_key == brn).first()
    if not company:
        raise HTTPException(status_code=404, detail="등록된 사업자가 없습니다.")
    return VerifyBusinessResponse(
        company_key=company.company_key,
        company_name=company.company_name,
        status=company.verification_status,
        industry_name=company.industry_name,
        requires_admin_review=company.requires_admin_review,
        admin_review_reason=company.admin_review_reason,
        trust_score=40 if company.requires_admin_review else 100,
        nts_api_matched=True,
        entity_type=company.entity_type,
    )


@router.get("/entitlements/contact", response_model=ContactEntitlementResponse)
def contact_entitlement(company_key: str, db: Session = Depends(get_db)):
    brn = normalize_brn(company_key)
    company = db.query(Company).filter(Company.company_key == brn).first()
    if not company:
        raise HTTPException(status_code=404, detail="기업을 찾을 수 없습니다.")
    result = evaluate_contact(db, company)
    return ContactEntitlementResponse(**result)


@router.post("/contact-events", response_model=ContactEntitlementResponse)
def log_contact_event(body: ContactEventRequest, db: Session = Depends(get_db)):
    brn = normalize_brn(body.company_key)
    company = db.query(Company).filter(Company.company_key == brn).first()
    if not company:
        raise HTTPException(status_code=404, detail="기업을 찾을 수 없습니다.")

    access = evaluate_contact(db, company)
    db.add(
        ContactEvent(
            company_key=brn,
            application_id=body.application_id,
            action=body.action,
            tier=body.tier,
            allowed=access["allowed"],
        )
    )
    db.commit()

    if access["allowed"] and not (
        company.partnership_tier in {"starter", "growth", "enterprise"}
        and company.monthly_subscription_active
    ):
        increment_contact(db, brn)
        access = evaluate_contact(db, company)

    return ContactEntitlementResponse(**access)
