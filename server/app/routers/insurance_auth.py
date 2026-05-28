from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.insurance_auth_models import InsuranceAuthSession, MonthlyReemployment
from app.permanent_commission_models import InsuranceVerificationLog
from app.services.insurance_verification_orchestrator import (
    InsuranceVerificationOrchestrator,
)

router = APIRouter(prefix="/v1/insurance-auth", tags=["insurance-auth"])

_orchestrator = InsuranceVerificationOrchestrator()


class StartAuthRequest(BaseModel):
    employment_id: str
    seeker_email: str
    auth_provider: str = Field(
        pattern="^(naver|kakao|toss|pass)$",
        description="간편인증 수단",
    )


class CompleteAuthRequest(BaseModel):
    session_id: str
    mock_ci: str | None = None


class ReverifyRequest(BaseModel):
    employment_id: str
    cycle_number: int = Field(ge=0)
    period_start: datetime
    period_end: datetime


@router.post("/sessions")
def start_auth_session(body: StartAuthRequest, db: Session = Depends(get_db)):
    try:
        return _orchestrator.start_auth_session(
            db,
            employment_id=body.employment_id,
            seeker_email=body.seeker_email,
            auth_provider=body.auth_provider,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/sessions/complete")
def complete_auth_and_verify(body: CompleteAuthRequest, db: Session = Depends(get_db)):
    try:
        return _orchestrator.complete_auth_and_verify(
            db,
            session_id=body.session_id,
            mock_ci=body.mock_ci,
        )
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.post("/reverify")
def reverify_employment(body: ReverifyRequest, db: Session = Depends(get_db)):
    try:
        return _orchestrator.reverify_employment(
            db,
            employment_id=body.employment_id,
            cycle_number=body.cycle_number,
            period_start=body.period_start,
            period_end=body.period_end,
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/verifications/{employment_id}")
def list_verifications(employment_id: str, db: Session = Depends(get_db)):
    rows = (
        db.query(InsuranceVerificationLog)
        .filter(InsuranceVerificationLog.employment_id == employment_id)
        .order_by(InsuranceVerificationLog.verified_at.desc())
        .all()
    )
    return [
        {
            "log_id": row.log_id,
            "workplace_name": row.workplace_name,
            "status": row.status,
            "verified_at": row.verified_at.isoformat(),
            "expires_at": row.expires_at.isoformat(),
            "auth_provider": row.auth_provider,
            "certificate_provider": row.certificate_provider,
            "cycle_number": row.cycle_number,
            "rejection_reason": row.rejection_reason,
        }
        for row in rows
    ]


@router.get("/reemployments/{employment_id}")
def list_reemployments(employment_id: str, db: Session = Depends(get_db)):
    rows = (
        db.query(MonthlyReemployment)
        .filter(MonthlyReemployment.employment_id == employment_id)
        .order_by(MonthlyReemployment.cycle_number.desc())
        .all()
    )
    return [
        {
            "reemployment_id": row.reemployment_id,
            "cycle_number": row.cycle_number,
            "period_start": row.period_start.isoformat(),
            "period_end": row.period_end.isoformat(),
            "status": row.status,
            "verification_log_id": row.verification_log_id,
            "failure_reason": row.failure_reason,
        }
        for row in rows
    ]


@router.get("/sessions/{session_id}")
def get_auth_session(session_id: str, db: Session = Depends(get_db)):
    row = (
        db.query(InsuranceAuthSession)
        .filter(InsuranceAuthSession.session_id == session_id)
        .first()
    )
    if row is None:
        raise HTTPException(status_code=404, detail="session_not_found")

    in_memory = _orchestrator._auth.get(session_id)
    status = in_memory.status if in_memory else row.status

    return {
        "session_id": row.session_id,
        "employment_id": row.employment_id,
        "auth_provider": row.auth_provider,
        "auth_backend": row.auth_backend,
        "status": status,
        "auth_completed": status == "completed" or row.status == "completed",
        "completed_at": row.completed_at.isoformat() if row.completed_at else None,
    }


@router.get("/callback")
def insurance_auth_callback(
    session_id: str,
    provider: str | None = None,
    tx_id: str | None = None,
    ci: str | None = None,
    db: Session = Depends(get_db),
):
    """Barocert/PortOne redirect — WebView 완료 후 딥링크 리다이렉트."""
    from fastapi.responses import RedirectResponse

    try:
        result = _orchestrator.handle_auth_callback(
            db,
            session_id=session_id,
            provider=provider,
            tx_id=tx_id,
            ci=ci,
        )
        return RedirectResponse(url=result["redirect_url"], status_code=302)
    except ValueError as exc:
        from app.config import settings

        scheme = settings.app_deep_link_scheme
        return RedirectResponse(
            url=f"{scheme}://insurance-auth/fail?session_id={session_id}&reason={exc}",
            status_code=302,
        )


@router.post("/batch/reverify")
def run_reverify_batch(db: Session = Depends(get_db)):
    """수동 배치 실행 (관리·cron)."""
    from app.jobs.reverify_batch_job import process_reverify_batch

    return process_reverify_batch(db)
