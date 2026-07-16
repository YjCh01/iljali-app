from datetime import datetime, timezone
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobPostRow
from app.services.auth_token_service import verify_token
from app.services.entitlement_service import normalize_brn
from app.services.workplace_service import resolve_or_create_workplace

router = APIRouter(prefix="/v1/job-board", tags=["job-board"])


class JobPostBody(BaseModel):
    id: str | None = None
    title: str
    company_name: str = ""
    company_key: str = ""
    warehouse_name: str = ""
    hourly_wage: str = ""
    work_schedule: str = ""
    summary: str = ""
    job_description: str = ""
    description_body_json: str = "{}"
    workplace_latitude: float | None = None
    workplace_longitude: float | None = None
    required_credential_ids_json: str = "[]"
    notification_settings_json: str = "{}"
    status: str = "recruiting"
    posted_by_email: str = ""
    posted_by_name: str = ""


class JobPostUpdate(BaseModel):
    title: str | None = None
    company_name: str | None = None
    warehouse_name: str | None = None
    hourly_wage: str | None = None
    work_schedule: str | None = None
    summary: str | None = None
    job_description: str | None = None
    description_body_json: str | None = None
    workplace_latitude: float | None = None
    workplace_longitude: float | None = None
    required_credential_ids_json: str | None = None
    notification_settings_json: str | None = None
    status: str | None = None


def _row_to_dict(row: JobPostRow) -> dict:
    return {
        "id": row.id,
        "title": row.title,
        "company_name": row.company_name,
        "company_key": row.company_key,
        "warehouse_name": row.warehouse_name,
        "hourly_wage": row.hourly_wage,
        "work_schedule": row.work_schedule,
        "summary": row.summary,
        "job_description": row.job_description or "",
        "description_body_json": row.description_body_json or "{}",
        "workplace_latitude": row.workplace_latitude,
        "workplace_longitude": row.workplace_longitude,
        "workplace_id": row.workplace_id,
        "required_credential_ids_json": row.required_credential_ids_json or "[]",
        "notification_settings_json": row.notification_settings_json or "{}",
        "status": row.status,
        "posted_by_email": row.posted_by_email,
        "posted_by_name": row.posted_by_name,
        "view_count": row.view_count,
        "map_impression_count": row.map_impression_count,
        "created_at": row.created_at.replace(tzinfo=timezone.utc).isoformat()
        if row.created_at
        else None,
        "updated_at": row.updated_at.replace(tzinfo=timezone.utc).isoformat()
        if row.updated_at
        else None,
    }


def _resolve_bearer(authorization: str | None) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="인증이 필요합니다.")
    token = authorization.split(" ", 1)[1].strip()
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="세션이 만료되었습니다.")
    return payload


def _assert_employer_company(payload: dict, company_key: str) -> None:
    member_type = str(payload.get("member_type", ""))
    if member_type not in ("employer", "corporate"):
        raise HTTPException(status_code=403, detail="기업회원만 공고를 관리할 수 있습니다.")
    token_key = normalize_brn(str(payload.get("company_key", "")))
    target_key = normalize_brn(company_key or "")
    if not token_key or not target_key or token_key != target_key:
        raise HTTPException(
            status_code=403,
            detail="다른 기업의 공고는 변경할 수 없습니다.",
        )


def _assert_can_mutate_row(payload: dict, row: JobPostRow) -> None:
    _assert_employer_company(payload, row.company_key or "")


@router.get("/posts")
def list_posts(db: Session = Depends(get_db)):
    rows = db.query(JobPostRow).order_by(JobPostRow.created_at.desc()).all()
    posts = [_row_to_dict(r) for r in rows]
    return {"posts": posts, "count": len(posts)}


@router.post("/posts")
def create_post(
    body: JobPostBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    _assert_employer_company(payload, body.company_key)
    post_id = body.id or f"post_{uuid4().hex[:12]}"
    if db.get(JobPostRow, post_id) is not None:
        raise HTTPException(status_code=409, detail="이미 존재하는 공고 ID")
    workplace_id = resolve_or_create_workplace(
        db,
        company_key=body.company_key,
        warehouse_name=body.warehouse_name,
        latitude=body.workplace_latitude,
        longitude=body.workplace_longitude,
    )
    row = JobPostRow(
        id=post_id,
        title=body.title,
        company_name=body.company_name,
        company_key=body.company_key,
        warehouse_name=body.warehouse_name,
        hourly_wage=body.hourly_wage,
        work_schedule=body.work_schedule,
        summary=body.summary,
        job_description=body.job_description or body.summary,
        description_body_json=body.description_body_json or "{}",
        workplace_latitude=body.workplace_latitude,
        workplace_longitude=body.workplace_longitude,
        workplace_id=workplace_id,
        required_credential_ids_json=body.required_credential_ids_json or "[]",
        notification_settings_json=body.notification_settings_json or "{}",
        status=body.status,
        posted_by_email=body.posted_by_email.strip().lower(),
        posted_by_name=body.posted_by_name,
        created_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


@router.get("/posts/{post_id}")
def get_post(post_id: str, db: Session = Depends(get_db)):
    row = db.get(JobPostRow, post_id)
    if row is None:
        raise HTTPException(status_code=404, detail="공고를 찾을 수 없습니다.")
    return _row_to_dict(row)


@router.post("/posts/{post_id}/view")
def record_post_view(post_id: str, db: Session = Depends(get_db)):
    row = db.get(JobPostRow, post_id)
    if row is None:
        raise HTTPException(status_code=404, detail="공고를 찾을 수 없습니다.")
    row.view_count = (row.view_count or 0) + 1
    db.commit()
    db.refresh(row)
    return {"post_id": post_id, "view_count": row.view_count}


@router.post("/posts/{post_id}/map-impression")
def record_map_impression(post_id: str, db: Session = Depends(get_db)):
    row = db.get(JobPostRow, post_id)
    if row is None:
        raise HTTPException(status_code=404, detail="공고를 찾을 수 없습니다.")
    row.map_impression_count = (row.map_impression_count or 0) + 1
    db.commit()
    db.refresh(row)
    return {"post_id": post_id, "map_impression_count": row.map_impression_count}


@router.put("/posts/{post_id}")
def update_post(
    post_id: str,
    body: JobPostUpdate,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    row = db.get(JobPostRow, post_id)
    if row is None:
        raise HTTPException(status_code=404, detail="공고를 찾을 수 없습니다.")
    payload = _resolve_bearer(authorization)
    _assert_can_mutate_row(payload, row)
    data = body.model_dump(exclude_none=True)
    for key, value in data.items():
        setattr(row, key, value)
    if {"warehouse_name", "workplace_latitude", "workplace_longitude"} & data.keys():
        row.workplace_id = resolve_or_create_workplace(
            db,
            company_key=row.company_key,
            warehouse_name=row.warehouse_name,
            latitude=row.workplace_latitude,
            longitude=row.workplace_longitude,
        )
    row.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


@router.delete("/posts/{post_id}")
def delete_post(
    post_id: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    row = db.get(JobPostRow, post_id)
    if row is None:
        raise HTTPException(status_code=404, detail="공고를 찾을 수 없습니다.")
    payload = _resolve_bearer(authorization)
    _assert_can_mutate_row(payload, row)
    db.delete(row)
    db.commit()
    return {"deleted": True, "id": post_id}
