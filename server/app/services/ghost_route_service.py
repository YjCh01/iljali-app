import json
from datetime import datetime, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.qc_models import AdminAuditLogRow, ClosedGhostRouteRow


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
            target_type="closed_ghost_route",
            target_id=target_id,
            detail_json=json.dumps(detail or {}, ensure_ascii=False),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
    )


def _parse_stops(raw: str) -> list[dict]:
    try:
        parsed = json.loads(raw or "[]")
    except json.JSONDecodeError:
        return []
    if not isinstance(parsed, list):
        return []
    stops = []
    for item in parsed:
        if not isinstance(item, dict):
            continue
        lat = item.get("latitude")
        lng = item.get("longitude")
        if lat is None or lng is None:
            continue
        stops.append({"latitude": float(lat), "longitude": float(lng)})
    return stops


def _row_to_dict(row: ClosedGhostRouteRow) -> dict:
    return {
        "id": row.id,
        "label": row.label or "",
        "workplace_latitude": row.workplace_latitude,
        "workplace_longitude": row.workplace_longitude,
        "stops": _parse_stops(row.stops_json),
        "ghost_pin_id": row.ghost_pin_id or "",
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


def list_ghost_routes(db: Session) -> list[dict]:
    rows = (
        db.query(ClosedGhostRouteRow)
        .order_by(ClosedGhostRouteRow.created_at.desc())
        .all()
    )
    return [_row_to_dict(row) for row in rows]


def create_ghost_route(
    db: Session,
    *,
    workplace_latitude: float,
    workplace_longitude: float,
    stops: list[dict],
    label: str = "",
) -> dict:
    route_id = f"ghost_route_{uuid4().hex[:12]}"
    normalized_stops = []
    for stop in stops:
        lat = stop.get("latitude")
        lng = stop.get("longitude")
        if lat is None or lng is None:
            continue
        normalized_stops.append(
            {"latitude": float(lat), "longitude": float(lng)},
        )

    row = ClosedGhostRouteRow(
        id=route_id,
        label=label.strip() or "종료된 셔틀 노선",
        workplace_latitude=workplace_latitude,
        workplace_longitude=workplace_longitude,
        stops_json=json.dumps(normalized_stops, ensure_ascii=False),
        ghost_pin_id="",
        created_at=datetime.now(timezone.utc).replace(tzinfo=None),
    )
    db.add(row)
    _audit(
        db,
        action="ghost_route.create",
        target_id=route_id,
        detail={
            "workplace_latitude": workplace_latitude,
            "workplace_longitude": workplace_longitude,
            "stop_count": len(normalized_stops),
        },
    )
    db.commit()
    db.refresh(row)
    return _row_to_dict(row)


def delete_ghost_route(db: Session, *, route_id: str) -> bool:
    row = db.get(ClosedGhostRouteRow, route_id)
    if row is None:
        return False
    db.delete(row)
    _audit(db, action="ghost_route.delete", target_id=route_id)
    db.commit()
    return True
