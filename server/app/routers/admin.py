from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AbuseFlag, Company
from app.qc_models import QcMemberRow
from app.schemas import (
    AbuseFlagResponse,
    AdminReviewRequest,
    BusinessRecordResponse,
    SubscribeRequest,
    SubscribeResponse,
)
from app.services.entitlement_service import get_or_create_company, normalize_brn

router = APIRouter(prefix="/v1/admin", tags=["admin"])
sub_router = APIRouter(prefix="/v1/subscriptions", tags=["subscriptions"])


@router.get("/compliance/flags", response_model=list[AbuseFlagResponse])
def list_flags(db: Session = Depends(get_db)):
    rows = db.query(AbuseFlag).order_by(AbuseFlag.created_at.desc()).limit(50).all()
    return [
        AbuseFlagResponse(
            id=r.id,
            company_key=r.company_key,
            type=r.type,
            severity=r.severity,
            message=r.message,
            created_at=r.created_at,
        )
        for r in rows
    ]


@router.get("/compliance/business-records", response_model=list[BusinessRecordResponse])
def list_business_records(db: Session = Depends(get_db)):
    rows = db.query(Company).order_by(Company.created_at.desc()).all()
    return [
        BusinessRecordResponse(
            company_key=r.company_key,
            company_name=r.company_name,
            industry_name=r.industry_name,
            verification_status=r.verification_status,
            requires_admin_review=r.requires_admin_review,
            admin_review_approved=r.admin_review_approved,
            is_suspended=r.is_suspended,
            partnership_tier=r.partnership_tier,
        )
        for r in rows
    ]


@router.patch("/companies/{company_key}/review")
def review_company(
    company_key: str, body: AdminReviewRequest, db: Session = Depends(get_db)
):
    brn = normalize_brn(company_key)
    company = db.query(Company).filter(Company.company_key == brn).first()
    if not company:
        member = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.company_key == brn)
            .filter(QcMemberRow.member_type == "corporate")
            .order_by(QcMemberRow.created_at.desc())
            .first()
        )
        if not member:
            raise HTTPException(status_code=404, detail="기업을 찾을 수 없습니다.")
        company = get_or_create_company(db, brn, member.company_name, "corporation")
        company.requires_admin_review = True
        company.verification_status = "pending"

    if body.approved:
        company.admin_review_approved = True
        company.verification_status = "verified"
        if company.partnership_tier == "enterprise" or company.requires_admin_review:
            company.requires_admin_review = True
        company.admin_review_reason = body.reason or "관리자 승인 완료"
    else:
        company.admin_review_approved = False
        company.verification_status = "rejected"
        company.admin_review_reason = body.reason or "관리자 승인 거부"

    db.commit()
    return {"company_key": brn, "status": company.verification_status}


@router.patch("/companies/{company_key}/suspend")
def suspend_company(company_key: str, db: Session = Depends(get_db)):
    brn = normalize_brn(company_key)
    company = db.query(Company).filter(Company.company_key == brn).first()
    if not company:
        raise HTTPException(status_code=404, detail="기업을 찾을 수 없습니다.")
    company.is_suspended = True
    company.verification_status = "suspended"
    db.add(
        AbuseFlag(
            company_key=brn,
            type="account_suspended",
            severity="critical",
            message="관리자에 의해 계정 정지",
        )
    )
    db.commit()
    return {"company_key": brn, "is_suspended": True}


from pydantic import BaseModel


class EnterpriseInquiryRequest(BaseModel):
    company_key: str
    company_name: str
    contact_person: str | None = None


@sub_router.post("/enterprise-inquiry")
def enterprise_inquiry(body: EnterpriseInquiryRequest, db: Session = Depends(get_db)):
    brn = normalize_brn(body.company_key)
    db.add(
        AbuseFlag(
            company_key=brn,
            type="enterprise_inquiry",
            severity="medium",
            message=f"Enterprise 맞춤 견적 요청 — {body.company_name}",
        )
    )
    company = db.query(Company).filter(Company.company_key == brn).first()
    if company:
        company.partnership_tier = "enterprise"
    db.commit()
    return {"accepted": True, "company_key": brn}


@sub_router.post("/subscribe", response_model=SubscribeResponse)
def subscribe(body: SubscribeRequest, db: Session = Depends(get_db)):
    brn = normalize_brn(body.company_key)
    company = db.query(Company).filter(Company.company_key == brn).first()
    if not company:
        raise HTTPException(status_code=404, detail="기업을 찾을 수 없습니다.")
    if company.requires_admin_review and not company.admin_review_approved:
        if body.tier != "enterprise":
            raise HTTPException(
                status_code=403,
                detail="업종 검토 대상 기업은 Enterprise 가입·관리자 승인 후 결제 가능합니다.",
            )

    company.partnership_tier = body.tier
    company.monthly_subscription_active = True
    company.subscription_expires_at = datetime.utcnow() + __import__("datetime").timedelta(days=30)
    db.commit()
    return SubscribeResponse(
        tier=body.tier,
        monthly_subscription_active=True,
        started_at=datetime.utcnow(),
    )
