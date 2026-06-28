from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobApplicationRow

from app.services.sanction_service import auto_seeker_noshow_sanction

router = APIRouter(prefix="/v1/hiring", tags=["hiring"])


class NoShowSanctionBody(BaseModel):
    seeker_email: str
    streak: int = 1


class ApplicationBody(BaseModel):
    post_id: str
    post_title: str = ""
    company_name: str = ""
    company_key: str = ""
    seeker_email: str
    seeker_name: str = ""
    status: str = "applied"
    work_schedule: str = ""


def _row_to_dict(row: JobApplicationRow) -> dict:
    return {
        "id": row.id,
        "post_id": row.post_id,
        "post_title": row.post_title,
        "company_name": row.company_name,
        "company_key": row.company_key,
        "seeker_email": row.seeker_email,
        "seeker_name": row.seeker_name,
        "status": row.status,
        "work_schedule": row.work_schedule,
        "applied_at": row.applied_at.replace(tzinfo=timezone.utc).isoformat()
        if row.applied_at
        else None,
    }


@router.get("/applications")
def list_applications(
    seeker_email: str | None = Query(default=None),
    company_key: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    query = db.query(JobApplicationRow)
    if seeker_email:
        query = query.filter(JobApplicationRow.seeker_email == seeker_email)
    if company_key:
        query = query.filter(JobApplicationRow.company_key == company_key)
    rows = query.order_by(JobApplicationRow.applied_at.desc()).all()
    items = [_row_to_dict(r) for r in rows]
    return {"applications": items, "count": len(items)}


@router.post("/applications")
def create_application(body: ApplicationBody, db: Session = Depends(get_db)):
    email = body.seeker_email.strip().lower()
    existing = (
        db.query(JobApplicationRow)
        .filter(
            JobApplicationRow.post_id == body.post_id,
            JobApplicationRow.seeker_email == email,
        )
        .order_by(JobApplicationRow.applied_at.desc())
        .first()
    )
    if existing is not None:
        return _row_to_dict(existing)

    row = JobApplicationRow(
        id=f"app_{uuid4().hex[:12]}",
        post_id=body.post_id,
        post_title=body.post_title,
        company_name=body.company_name,
        company_key=body.company_key,
        seeker_email=email,
        seeker_name=body.seeker_name,
        status=body.status,
        work_schedule=body.work_schedule,
        applied_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


@router.get("/applications/{application_id}")
def get_application(application_id: str, db: Session = Depends(get_db)):
    row = db.get(JobApplicationRow, application_id)
    if row is None:
        raise HTTPException(status_code=404, detail="지원 내역을 찾을 수 없습니다.")
    return _row_to_dict(row)


@router.post("/seeker/no-show/sync")
def sync_seeker_noshow_sanction(
    body: NoShowSanctionBody, db: Session = Depends(get_db)
):
    """No-show 누적 → 구직자 자동 주의/경고 (셔틀·근무 연동)."""
    result = auto_seeker_noshow_sanction(
        db, email=body.seeker_email, streak=body.streak
    )
    if result is None:
        return {"applied": False}
    return {"applied": True, "sanction": result}
