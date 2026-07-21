"""위치정보의 이용ㆍ제공사실 확인 자료 기록 — 위치정보법상 취급대장."""

from __future__ import annotations

import json
from uuid import uuid4

from sqlalchemy.orm import Session

from app.job_sync_models import LocationUsageLogRow


def record_usage(
    db: Session,
    *,
    usage_type: str,
    subject_label: str,
    subject_email: str,
    acquisition_path: str,
    service_description: str,
    recipient_label: str,
    latitude: float | None = None,
    longitude: float | None = None,
    detail: dict | None = None,
) -> LocationUsageLogRow:
    row = LocationUsageLogRow(
        id=f"loc_{uuid4().hex[:16]}",
        usage_type=usage_type,
        subject_label=subject_label,
        subject_email=(subject_email or "").strip().lower(),
        acquisition_path=acquisition_path,
        service_description=service_description,
        recipient_label=recipient_label,
        latitude=latitude,
        longitude=longitude,
        detail_json=json.dumps(detail or {}, ensure_ascii=False),
    )
    db.add(row)
    db.commit()
    return row


def list_usage_logs(
    db: Session,
    *,
    usage_type: str | None = None,
    limit: int = 100,
) -> list[dict]:
    query = db.query(LocationUsageLogRow)
    if usage_type:
        query = query.filter(LocationUsageLogRow.usage_type == usage_type)
    rows = (
        query.order_by(LocationUsageLogRow.created_at.desc())
        .limit(max(1, min(limit, 500)))
        .all()
    )
    return [
        {
            "id": r.id,
            "usage_type": r.usage_type,
            "subject_label": r.subject_label,
            "subject_email": r.subject_email,
            "acquisition_path": r.acquisition_path,
            "service_description": r.service_description,
            "recipient_label": r.recipient_label,
            "latitude": r.latitude,
            "longitude": r.longitude,
            "detail": json.loads(r.detail_json or "{}"),
            "created_at": r.created_at,
        }
        for r in rows
    ]
