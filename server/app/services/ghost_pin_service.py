import json
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.qc_models import AdminAuditLogRow, ClosedGhostPinRow


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
            target_type="closed_ghost_pin",
            target_id=target_id,
            detail_json=json.dumps(detail or {}, ensure_ascii=False),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
    )


def _row_to_dict(row: ClosedGhostPinRow) -> dict:
    return {
        "id": row.id,
        "latitude": row.latitude,
        "longitude": row.longitude,
        "label": row.label or "",
        "source_post_id": row.source_post_id or "",
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def list_ghost_pins(db: Session) -> list[dict]:
    rows = (
        db.query(ClosedGhostPinRow)
        .order_by(ClosedGhostPinRow.created_at.desc())
        .all()
    )
    return [_row_to_dict(row) for row in rows]


def create_ghost_pin(
    db: Session,
    *,
    latitude: float,
    longitude: float,
    label: str = "",
    source_post_id: str = "",
) -> dict:
    pin_id = f"ghost_{uuid4().hex[:12]}"
    row = ClosedGhostPinRow(
        id=pin_id,
        latitude=latitude,
        longitude=longitude,
        label=label.strip(),
        source_post_id=source_post_id.strip(),
        created_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    _audit(
        db,
        action="ghost_pin.create",
        target_id=pin_id,
        detail={
            "latitude": latitude,
            "longitude": longitude,
            "label": label,
            "source_post_id": source_post_id,
        },
    )
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


def delete_ghost_pin(db: Session, *, pin_id: str) -> bool:
    row = db.get(ClosedGhostPinRow, pin_id)
    if row is None:
        return False
    db.delete(row)
    _audit(db, action="ghost_pin.delete", target_id=pin_id)
    db.commit()
    return True
