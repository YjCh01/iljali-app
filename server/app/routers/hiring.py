from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobApplicationRow
from app.qc_models import QcMemberRow
from app.routers.job_board import _assert_employer_company, _resolve_bearer
from app.services.chat_message_service import clear_messages
from app.services.push_dispatch_hooks import (
    push_interview_confirmed,
    push_new_applicant,
    push_work_schedule_confirmed,
)

router = APIRouter(prefix="/v1/hiring", tags=["hiring"])


class ApplicationBody(BaseModel):
    post_id: str
    post_title: str = ""
    company_name: str = ""
    company_key: str = ""
    seeker_email: str
    seeker_name: str = ""
    status: str = "applied"
    work_schedule: str = ""
    commute_route_id: str = ""
    commute_route_name: str = ""
    shuttle_stop_id: str = ""
    shuttle_stop_label: str = ""
    shuttle_pickup_time: str = ""
    shuttle_shift_date: str = ""
    required_credential_ids_json: str = "[]"
    held_credential_ids_json: str = "[]"
    work_date: str = ""
    interview_at: str = ""


def _assert_self_email(payload: dict, email: str) -> None:
    token_email = str(payload.get("sub", "")).strip().lower()
    if not token_email or token_email != email.strip().lower():
        raise HTTPException(status_code=403, detail="본인 정보만 조회할 수 있습니다.")


def _assert_seeker_identity(payload: dict, seeker_email: str) -> None:
    member_type = str(payload.get("member_type", ""))
    if member_type != "seeker":
        raise HTTPException(status_code=403, detail="구직자 본인만 조회할 수 있습니다.")
    _assert_self_email(payload, seeker_email)


def _seeker_no_show_count(db: Session, seeker_email: str) -> int:
    seeker = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == (seeker_email or "").lower())
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    return seeker.no_show_count if seeker is not None else 0


def _row_to_dict(row: JobApplicationRow, db: Session) -> dict:
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
        "commute_route_id": row.commute_route_id,
        "commute_route_name": row.commute_route_name,
        "shuttle_stop_id": row.shuttle_stop_id,
        "shuttle_stop_label": row.shuttle_stop_label,
        "shuttle_pickup_time": row.shuttle_pickup_time,
        "shuttle_shift_date": row.shuttle_shift_date,
        "required_credential_ids_json": row.required_credential_ids_json or "[]",
        "held_credential_ids_json": row.held_credential_ids_json or "[]",
        "work_date": row.work_date or "",
        "interview_at": row.interview_at or "",
        "seeker_no_show_count": _seeker_no_show_count(db, row.seeker_email),
        "applied_at": row.applied_at.replace(tzinfo=timezone.utc).isoformat()
        if row.applied_at
        else None,
    }


@router.get("/applications")
def list_applications(
    seeker_email: str | None = Query(default=None),
    company_key: str | None = Query(default=None),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    if not seeker_email and not company_key:
        raise HTTPException(
            status_code=400, detail="seeker_email 또는 company_key가 필요합니다."
        )
    payload = _resolve_bearer(authorization)
    if company_key:
        _assert_employer_company(payload, company_key)
    else:
        _assert_seeker_identity(payload, seeker_email)  # type: ignore[arg-type]

    query = db.query(JobApplicationRow)
    if seeker_email:
        query = query.filter(JobApplicationRow.seeker_email == seeker_email)
    if company_key:
        query = query.filter(JobApplicationRow.company_key == company_key)
    rows = query.order_by(JobApplicationRow.applied_at.desc()).all()
    items = [_row_to_dict(r, db) for r in rows]
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
        was_scheduled = existing.status == "scheduled"
        had_interview_before = bool(existing.interview_at)

        existing.status = body.status
        existing.work_schedule = body.work_schedule
        existing.company_key = body.company_key or existing.company_key
        existing.company_name = body.company_name or existing.company_name
        existing.commute_route_id = body.commute_route_id.strip()
        existing.commute_route_name = body.commute_route_name.strip()
        existing.shuttle_stop_id = body.shuttle_stop_id.strip()
        existing.shuttle_stop_label = body.shuttle_stop_label.strip()
        existing.shuttle_pickup_time = body.shuttle_pickup_time.strip()
        existing.shuttle_shift_date = body.shuttle_shift_date.strip()
        existing.required_credential_ids_json = body.required_credential_ids_json or "[]"
        existing.held_credential_ids_json = body.held_credential_ids_json or "[]"
        new_work_date = body.work_date.strip()
        if new_work_date and new_work_date != existing.work_date:
            existing.work_date = new_work_date
            # 근무일이 바뀌면(재협의 등) 이전 근무일 기준으로 보낸 리마인더 상태를 초기화.
            existing.work_reminder_sent_at = None
        new_interview_at = body.interview_at.strip()
        if new_interview_at and new_interview_at != existing.interview_at:
            existing.interview_at = new_interview_at
            existing.interview_reminder_sent_at = None
        db.commit()
        db.refresh(existing)

        if not was_scheduled and existing.status == "scheduled":
            push_work_schedule_confirmed(db, application_id=existing.id)
        if new_interview_at and not had_interview_before:
            push_interview_confirmed(db, application_id=existing.id)

        return _row_to_dict(existing, db)

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
        commute_route_id=body.commute_route_id.strip(),
        commute_route_name=body.commute_route_name.strip(),
        shuttle_stop_id=body.shuttle_stop_id.strip(),
        shuttle_stop_label=body.shuttle_stop_label.strip(),
        shuttle_pickup_time=body.shuttle_pickup_time.strip(),
        shuttle_shift_date=body.shuttle_shift_date.strip(),
        required_credential_ids_json=body.required_credential_ids_json or "[]",
        held_credential_ids_json=body.held_credential_ids_json or "[]",
        work_date=body.work_date.strip(),
        interview_at=body.interview_at.strip(),
        applied_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    push_new_applicant(db, application_id=row.id)
    return _row_to_dict(row, db)


@router.delete("/applications")
def withdraw_application(
    post_id: str = Query(..., min_length=1),
    seeker_email: str = Query(..., min_length=3),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """구직자 지원 취소 — 동일 공고·이메일 지원 건 전부 삭제 (sync 재유입 방지)."""
    payload = _resolve_bearer(authorization)
    _assert_seeker_identity(payload, seeker_email)
    email = seeker_email.strip().lower()
    rows = (
        db.query(JobApplicationRow)
        .filter(
            JobApplicationRow.post_id == post_id,
            JobApplicationRow.seeker_email == email,
        )
        .all()
    )
    if not rows:
        return {"withdrawn": False, "deleted": 0}

    deleted = 0
    for row in rows:
        clear_messages(db, row.id)
        db.delete(row)
        deleted += 1
    db.commit()
    return {"withdrawn": True, "deleted": deleted}


@router.get("/applications/{application_id}")
def get_application(application_id: str, db: Session = Depends(get_db)):
    row = db.get(JobApplicationRow, application_id)
    if row is None:
        raise HTTPException(status_code=404, detail="지원 내역을 찾을 수 없습니다.")
    return _row_to_dict(row, db)


@router.post("/applications/{application_id}/mark-no-show")
def mark_no_show(
    application_id: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """기업이 지원자를 노쇼 처리 — 다른 기업도 열람 가능한 서버 카운트로 누적."""
    payload = _resolve_bearer(authorization)
    application = db.get(JobApplicationRow, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="지원 내역을 찾을 수 없습니다.")
    _assert_employer_company(payload, application.company_key or "")

    application.status = "no_show"

    seeker = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == (application.seeker_email or "").lower())
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    if seeker is not None:
        seeker.no_show_count = (seeker.no_show_count or 0) + 1

    db.commit()
    db.refresh(application)
    return _row_to_dict(application, db)
