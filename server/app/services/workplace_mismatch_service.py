"""근무지·본사 주소 불일치 — 기업 신고 및 어드민 승인."""

from datetime import datetime, timezone

from fastapi import HTTPException
from sqlalchemy.orm import Session

from app.job_sync_models import JobPostRow
from app.models import AbuseFlag
from app.services.entitlement_service import normalize_brn

WORKPLACE_MISMATCH_TYPE = "workplaceMismatch"


def _flag_to_dict(row: AbuseFlag) -> dict:
    return {
        "id": row.id,
        "company_key": row.company_key or "",
        "company_name": row.company_name or "",
        "post_id": row.post_id or "",
        "post_title": row.post_title or "",
        "head_office_address": row.head_office_address or "",
        "workplace_address": row.workplace_address or "",
        "distance_meters": row.distance_meters,
        "review_status": row.review_status or "pending",
        "message": row.message,
        "severity": row.severity,
        "created_at": row.created_at.replace(tzinfo=timezone.utc).isoformat()
        if row.created_at
        else None,
    }


def report_workplace_mismatch(
    db: Session,
    *,
    company_key: str,
    company_name: str = "",
    head_office_address: str = "",
    workplace_address: str = "",
    post_id: str = "",
    post_title: str = "",
    distance_meters: int | None = None,
    reason: str | None = None,
) -> dict:
    brn = normalize_brn(company_key)
    if not brn:
        raise HTTPException(status_code=400, detail="사업자등록번호가 필요합니다.")
    if post_id:
        existing = (
            db.query(AbuseFlag)
            .filter(AbuseFlag.type == WORKPLACE_MISMATCH_TYPE)
            .filter(AbuseFlag.post_id == post_id)
            .filter(AbuseFlag.review_status == "pending")
            .filter(AbuseFlag.resolved.is_(False))
            .first()
        )
        if existing is not None:
            return _flag_to_dict(existing)

    row = AbuseFlag(
        company_key=brn,
        company_name=company_name,
        type=WORKPLACE_MISMATCH_TYPE,
        severity="high",
        message=reason or "실근무지와 사업자 소재지 불일치 — 어드민 검토 대상",
        post_id=post_id or None,
        post_title=post_title or None,
        head_office_address=head_office_address or None,
        workplace_address=workplace_address or None,
        distance_meters=distance_meters,
        review_status="pending",
        resolved=False,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _flag_to_dict(row)


def list_pending_workplace_mismatch_flags(db: Session, *, limit: int = 100) -> list[dict]:
    rows = (
        db.query(AbuseFlag)
        .filter(AbuseFlag.type == WORKPLACE_MISMATCH_TYPE)
        .filter(AbuseFlag.review_status == "pending")
        .filter(AbuseFlag.resolved.is_(False))
        .order_by(AbuseFlag.created_at.desc())
        .limit(limit)
        .all()
    )
    return [_flag_to_dict(r) for r in rows]


def approve_stated_workplace_post(db: Session, *, flag_id: int) -> dict:
    row = db.get(AbuseFlag, flag_id)
    if row is None or row.type != WORKPLACE_MISMATCH_TYPE:
        raise HTTPException(status_code=404, detail="검토 항목을 찾을 수 없습니다.")
    if row.review_status != "pending" or row.resolved:
        raise HTTPException(status_code=409, detail="이미 처리된 검토 항목입니다.")

    post_id = (row.post_id or "").strip()
    if not post_id:
        raise HTTPException(status_code=422, detail="연결된 공고 ID가 없습니다.")

    post = db.get(JobPostRow, post_id)
    if post is None:
        raise HTTPException(
            status_code=404,
            detail=f"공고를 찾을 수 없습니다. ({post_id})",
        )

    now = datetime.now(timezone.utc).replace(tzinfo=None)
    post.status = "recruiting"
    post.updated_at = now

    row.resolved = True
    row.review_status = "approved"
    row.resolved_action = "publish_stated_workplace"
    row.resolved_at = now

    db.commit()
    db.refresh(row)
    db.refresh(post)

    return {
        "flag": _flag_to_dict(row),
        "post_id": post.id,
        "post_status": post.status,
    }
