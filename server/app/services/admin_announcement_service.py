import json
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.qc_models import AdminAnnouncementRow, AdminAuditLogRow
from app.services.push_dispatch_hooks import push_admin_announcement


def _audit(
    db: Session,
    *,
    action: str,
    target_id: str,
    detail: dict | None = None,
) -> None:
    db.add(
        AdminAuditLogRow(
            id=f"audit_{uuid4().hex[:12]}",
            action=action,
            target_type="admin_announcement",
            target_id=target_id,
            detail_json=json.dumps(detail or {}, ensure_ascii=False),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
    )


VALID_AUDIENCES = frozenset({"all", "seeker", "corporate"})


def _normalize_audience(audience: str | None) -> str:
    value = (audience or "all").strip().lower()
    if value not in VALID_AUDIENCES:
        return "all"
    return value


def _audience_visible(audience: str, member_type: str | None) -> bool:
    normalized = _normalize_audience(audience)
    if normalized == "all":
        return True
    if not member_type:
        return False
    member = member_type.strip().lower()
    if member in {"seeker", "individual"}:
        return normalized == "seeker"
    if member in {"corporate", "employer"}:
        return normalized == "corporate"
    return False


def _row_to_dict(row: AdminAnnouncementRow) -> dict:
    return {
        "id": row.id,
        "title": row.title or "",
        "body": row.body or "",
        "audience": _normalize_audience(row.audience),
        "push_requested": bool(row.push_requested),
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def list_announcements(
    db: Session,
    *,
    limit: int = 100,
    member_type: str | None = None,
) -> list[dict]:
    rows = (
        db.query(AdminAnnouncementRow)
        .order_by(AdminAnnouncementRow.created_at.desc())
        .limit(limit)
        .all()
    )
    if member_type is None:
        return [_row_to_dict(row) for row in rows]
    return [
        _row_to_dict(row)
        for row in rows
        if _audience_visible(row.audience or "all", member_type)
    ]


def create_announcement(
    db: Session,
    *,
    title: str,
    body: str,
    audience: str = "all",
    push_requested: bool = True,
) -> dict:
    announcement_id = f"announce_{uuid4().hex[:12]}"
    row = AdminAnnouncementRow(
        id=announcement_id,
        title=title.strip(),
        body=body.strip(),
        audience=_normalize_audience(audience),
        push_requested=push_requested,
        created_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    _audit(
        db,
        action="announcement.create",
        target_id=announcement_id,
        detail={
            "title": title,
            "audience": _normalize_audience(audience),
            "push_requested": push_requested,
            "body_preview": body.strip()[:120],
        },
    )
    db.commit()
    db.refresh(row)
    result = _row_to_dict(row)
    push_result = push_admin_announcement(db, announcement=result)
    result["push_dispatched"] = push_result.get("sent", 0) > 0
    result["push_channel"] = "fcm_in_app_chat_notice"
    result["push_result"] = push_result
    return result
