"""어드민 이벤트핑 — 퀴즈·투표·안내."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.qc_models import AdminAuditLogRow, EventPinRow

_ALLOWED_KINDS = frozenset({"info", "quiz", "vote"})


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
            target_type="event_pin",
            target_id=target_id,
            detail_json=json.dumps(detail or {}, ensure_ascii=False),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
    )


def _normalize_color(hex_color: str) -> str:
    value = (hex_color or "").strip()
    if not value:
        return "#FF6F00"
    if not value.startswith("#"):
        value = f"#{value}"
    if len(value) not in (4, 7):
        return "#FF6F00"
    return value.upper()


def _normalize_payload(raw: dict | str | None) -> str:
    if isinstance(raw, str):
        try:
            parsed = json.loads(raw or "{}")
        except json.JSONDecodeError:
            parsed = {}
    elif isinstance(raw, dict):
        parsed = raw
    else:
        parsed = {}
    options = parsed.get("options")
    if not isinstance(options, list):
        options = []
    clean_options = [str(o).strip() for o in options if str(o).strip()][:8]
    correct = parsed.get("correct_index")
    payload: dict = {"options": clean_options}
    if isinstance(correct, int) and 0 <= correct < len(clean_options):
        payload["correct_index"] = correct
    return json.dumps(payload, ensure_ascii=False)


def _row_to_dict(row: EventPinRow) -> dict:
    try:
        payload = json.loads(row.payload_json or "{}")
    except json.JSONDecodeError:
        payload = {}
    return {
        "id": row.id,
        "latitude": row.latitude,
        "longitude": row.longitude,
        "title": row.title or "",
        "body": row.body or "",
        "kind": row.kind or "info",
        "color_hex": row.color_hex or "#FF6F00",
        "payload": payload if isinstance(payload, dict) else {},
        "active": bool(row.active),
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def list_event_pins(db: Session, *, active_only: bool = False) -> list[dict]:
    query = db.query(EventPinRow)
    if active_only:
        query = query.filter(EventPinRow.active.is_(True))
    rows = query.order_by(EventPinRow.created_at.desc()).all()
    return [_row_to_dict(row) for row in rows]


def create_event_pin(
    db: Session,
    *,
    latitude: float,
    longitude: float,
    title: str = "",
    body: str = "",
    kind: str = "info",
    color_hex: str = "#FF6F00",
    payload: dict | str | None = None,
    active: bool = True,
) -> dict:
    kind_norm = (kind or "info").strip().lower()
    if kind_norm not in _ALLOWED_KINDS:
        raise ValueError("kind는 info|quiz|vote 중 하나여야 합니다.")
    pin_id = f"event_{uuid4().hex[:12]}"
    row = EventPinRow(
        id=pin_id,
        latitude=latitude,
        longitude=longitude,
        title=(title or "").strip()[:200],
        body=(body or "").strip()[:4000],
        kind=kind_norm,
        color_hex=_normalize_color(color_hex),
        payload_json=_normalize_payload(payload),
        active=active,
        created_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    _audit(
        db,
        action="event_pin.create",
        target_id=pin_id,
        detail={
            "latitude": latitude,
            "longitude": longitude,
            "title": row.title,
            "kind": kind_norm,
        },
    )
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


def delete_event_pin(db: Session, *, pin_id: str) -> bool:
    row = db.get(EventPinRow, pin_id.strip())
    if row is None:
        return False
    db.delete(row)
    _audit(db, action="event_pin.delete", target_id=pin_id)
    db.commit()
    return True
