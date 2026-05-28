from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.permanent_commission_models import (
    InsuranceVerificationLog,
    MonthlyCommission,
    PermanentEmployment,
)

router = APIRouter(prefix="/v1/permanent-commission", tags=["permanent-commission"])

COMMISSION_RATE = 0.055
BILLING_CYCLE_DAYS = 30


class RegisterEmploymentRequest(BaseModel):
    employment_id: str
    application_id: str
    company_key: str
    company_name: str
    seeker_email: str
    seeker_name: str
    monthly_salary_krw: int = Field(gt=0)
    hire_date: datetime


class InsuranceVerifyRequest(BaseModel):
    log_id: str
    employment_id: str
    workplace_name: str
    employer_company_name: str
    company_name_matched: bool
    employed_confirmed: bool
    verified_at: datetime
    expires_at: datetime
    status: str
    method: str = "simple_auth"
    rejection_reason: str | None = None
    ci_hash: str | None = None
    auth_provider: str | None = None
    certificate_provider: str | None = None
    cycle_number: int = 0
    simple_auth_session_id: str | None = None


class MonthlyCommissionRequest(BaseModel):
    commission_id: str
    employment_id: str
    period_start: datetime
    period_end: datetime
    monthly_salary_krw: int
    commission_rate: float = COMMISSION_RATE
    amount_krw: int
    status: str
    charged_at: datetime | None = None
    skip_reason: str | None = None


@router.post("/employments")
def register_employment(body: RegisterEmploymentRequest, db: Session = Depends(get_db)):
    row = PermanentEmployment(
        employment_id=body.employment_id,
        application_id=body.application_id,
        company_key=body.company_key,
        company_name=body.company_name,
        seeker_email=body.seeker_email,
        seeker_name=body.seeker_name,
        monthly_salary_krw=body.monthly_salary_krw,
        hire_date=body.hire_date,
    )
    db.add(row)
    db.commit()
    return {"ok": True, "employment_id": body.employment_id}


@router.get("/employments/{company_key}")
def list_employments(company_key: str, db: Session = Depends(get_db)):
    rows = (
        db.query(PermanentEmployment)
        .filter(
            PermanentEmployment.company_key == company_key,
            PermanentEmployment.active.is_(True),
        )
        .all()
    )
    return [
        {
            "employment_id": row.employment_id,
            "seeker_name": row.seeker_name,
            "monthly_salary_krw": row.monthly_salary_krw,
            "hire_date": row.hire_date.isoformat(),
            "expected_commission_krw": round(row.monthly_salary_krw * COMMISSION_RATE),
        }
        for row in rows
    ]


@router.post("/insurance-verifications")
def save_insurance_verification(
    body: InsuranceVerifyRequest, db: Session = Depends(get_db)
):
    row = InsuranceVerificationLog(
        log_id=body.log_id,
        employment_id=body.employment_id,
        workplace_name=body.workplace_name,
        employer_company_name=body.employer_company_name,
        company_name_matched=body.company_name_matched,
        employed_confirmed=body.employed_confirmed,
        verified_at=body.verified_at,
        expires_at=body.expires_at,
        status=body.status,
        method=body.method,
        rejection_reason=body.rejection_reason,
        ci_hash=body.ci_hash,
        auth_provider=body.auth_provider,
        certificate_provider=body.certificate_provider,
        cycle_number=body.cycle_number,
        simple_auth_session_id=body.simple_auth_session_id,
    )
    db.add(row)
    db.commit()
    return {"ok": True}


@router.post("/monthly-commissions")
def save_monthly_commission(
    body: MonthlyCommissionRequest, db: Session = Depends(get_db)
):
    row = MonthlyCommission(
        commission_id=body.commission_id,
        employment_id=body.employment_id,
        period_start=body.period_start,
        period_end=body.period_end,
        monthly_salary_krw=body.monthly_salary_krw,
        commission_rate=body.commission_rate,
        amount_krw=body.amount_krw,
        status=body.status,
        charged_at=body.charged_at,
        skip_reason=body.skip_reason,
    )
    db.add(row)
    db.commit()
    return {"ok": True}
