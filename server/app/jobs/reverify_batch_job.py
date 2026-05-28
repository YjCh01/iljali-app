"""30일 주기 재직 확인 + 수수료 생성 배치."""

from __future__ import annotations

import logging
import uuid
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.permanent_commission_models import (
    InsuranceVerificationLog,
    MonthlyCommission,
    PermanentEmployment,
)
from app.services.insurance_verification_orchestrator import (
    COMMISSION_RATE,
    InsuranceVerificationOrchestrator,
    VERIFICATION_VALIDITY_DAYS,
)

logger = logging.getLogger(__name__)

BILLING_CYCLE_DAYS = VERIFICATION_VALIDITY_DAYS


def _billing_due_at(hire_date: datetime, cycle_index: int) -> datetime:
    return hire_date + timedelta(days=BILLING_CYCLE_DAYS * (cycle_index + 1))


def process_reverify_batch(db: Session) -> dict:
    """만료 임박·청구 주기 도래 재직자에 대해 reverify + commission 생성."""
    orchestrator = InsuranceVerificationOrchestrator()
    now = datetime.utcnow()
    processed = 0
    reverified = 0
    commissions_created = 0
    skipped = 0

    employments = (
        db.query(PermanentEmployment)
        .filter(PermanentEmployment.active.is_(True))
        .all()
    )

    for employment in employments:
        processed += 1
        existing_commissions = (
            db.query(MonthlyCommission)
            .filter(MonthlyCommission.employment_id == employment.employment_id)
            .count()
        )
        cycle_index = existing_commissions
        due_at = _billing_due_at(employment.hire_date, cycle_index)

        if now < due_at:
            continue

        period_start = (
            employment.hire_date
            if cycle_index == 0
            else _billing_due_at(employment.hire_date, cycle_index - 1)
        )
        period_end = due_at

        already = (
            db.query(MonthlyCommission)
            .filter(
                MonthlyCommission.employment_id == employment.employment_id,
                MonthlyCommission.period_end == period_end,
            )
            .first()
        )
        if already:
            continue

        latest_log = (
            db.query(InsuranceVerificationLog)
            .filter(InsuranceVerificationLog.employment_id == employment.employment_id)
            .order_by(InsuranceVerificationLog.verified_at.desc())
            .first()
        )

        valid = (
            latest_log is not None
            and latest_log.status == "verified"
            and latest_log.company_name_matched
            and latest_log.employed_confirmed
            and latest_log.verified_at <= now < latest_log.expires_at
        )

        if not valid and cycle_index > 0:
            try:
                result = orchestrator.reverify_employment(
                    db,
                    employment_id=employment.employment_id,
                    cycle_number=cycle_index,
                    period_start=period_start,
                    period_end=period_end,
                )
                reverified += 1
                valid = result.get("success", False)
            except Exception as exc:
                logger.warning("reverify failed %s: %s", employment.employment_id, exc)

        if valid:
            amount = round(employment.monthly_salary_krw * COMMISSION_RATE)
            db.add(
                MonthlyCommission(
                    commission_id=f"mc_{uuid.uuid4().hex[:12]}",
                    employment_id=employment.employment_id,
                    period_start=period_start,
                    period_end=period_end,
                    monthly_salary_krw=employment.monthly_salary_krw,
                    commission_rate=COMMISSION_RATE,
                    amount_krw=amount,
                    status="pending",
                )
            )
            commissions_created += 1
        else:
            db.add(
                MonthlyCommission(
                    commission_id=f"mc_skip_{uuid.uuid4().hex[:12]}",
                    employment_id=employment.employment_id,
                    period_start=period_start,
                    period_end=period_end,
                    monthly_salary_krw=employment.monthly_salary_krw,
                    commission_rate=COMMISSION_RATE,
                    amount_krw=0,
                    status="skipped",
                    skip_reason="재직 확인 실패 또는 인증 만료",
                )
            )
            skipped += 1

        db.commit()

    return {
        "processed": processed,
        "reverified": reverified,
        "commissions_created": commissions_created,
        "skipped": skipped,
        "ran_at": now.isoformat(),
    }
