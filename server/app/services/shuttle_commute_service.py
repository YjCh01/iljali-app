"""통근 셔틀 — 노선·공유·구직자 선택."""

from __future__ import annotations

import json
from datetime import datetime

from sqlalchemy.orm import Session

from app.job_sync_models import JobApplicationRow
from app.services.route_geometry_service import apply_road_geometry_to_route
from app.shuttle_models import (
    CommuteRouteRow,
    SeekerShuttlePreferenceRow,
    ShuttleRouteShareConsentRow,
)


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _normalize_company_key(key: str) -> str:
    return key.strip()


def _consent_id(seeker_email: str, company_key: str) -> str:
    return f"{_normalize_email(seeker_email)}|{_normalize_company_key(company_key)}"


def _preference_id(seeker_email: str, company_key: str) -> str:
    return _consent_id(seeker_email, company_key)


def _parse_route_json(raw: str) -> dict:
    try:
        parsed = json.loads(raw or "{}")
        if isinstance(parsed, dict):
            return parsed
    except json.JSONDecodeError:
        pass
    return {}


def _route_row_to_dict(row: CommuteRouteRow) -> dict:
    data = _parse_route_json(row.route_json)
    data.setdefault("id", row.id)
    data.setdefault("companyKey", row.company_key)
    data["active"] = row.active
    return data


def _consent_row_to_dict(row: ShuttleRouteShareConsentRow) -> dict:
    return {
        "id": row.id,
        "seeker_email": row.seeker_email,
        "company_key": row.company_key,
        "company_name": row.company_name,
        "application_id": row.application_id,
        "offered_at": row.offered_at.isoformat() if row.offered_at else None,
        "opted_in": row.opted_in,
        "tower_participation_consented": row.tower_participation_consented,
        "route_id": row.route_id,
        "stop_id": row.stop_id,
        "pickup_time": row.pickup_time,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _preference_row_to_dict(row: SeekerShuttlePreferenceRow) -> dict:
    return {
        "id": row.id,
        "seeker_email": row.seeker_email,
        "company_key": row.company_key,
        "company_name": row.company_name,
        "route_id": row.route_id,
        "route_name": row.route_name,
        "stop_id": row.stop_id,
        "stop_label": row.stop_label,
        "pickup_time": row.pickup_time,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def seeker_may_view_company_routes(
    db: Session,
    *,
    seeker_email: str,
    company_key: str,
) -> bool:
    normalized = _normalize_email(seeker_email)
    company = _normalize_company_key(company_key)
    consent = db.get(ShuttleRouteShareConsentRow, _consent_id(normalized, company))
    if consent is not None and consent.opted_in:
        return True
    hired = (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.seeker_email == normalized)
        .filter(JobApplicationRow.company_key == company)
        .filter(JobApplicationRow.status.in_(["scheduled", "checked_in", "commission_paid"]))
        .first()
    )
    return hired is not None


def list_routes_for_company(
    db: Session,
    *,
    company_key: str,
    active_only: bool = True,
) -> list[dict]:
    company = _normalize_company_key(company_key)
    query = db.query(CommuteRouteRow).filter(CommuteRouteRow.company_key == company)
    if active_only:
        query = query.filter(CommuteRouteRow.active.is_(True))
    rows = query.order_by(CommuteRouteRow.updated_at.desc()).all()
    return [_route_row_to_dict(row) for row in rows]


def get_route_by_id(db: Session, *, route_id: str) -> dict | None:
    row = db.get(CommuteRouteRow, route_id.strip())
    if row is None:
        return None
    return _route_row_to_dict(row)


def upsert_commute_route(
    db: Session,
    *,
    route: dict,
    densify_geometry: bool = True,
) -> dict:
    route_id = str(route.get("id", "")).strip()
    company_key = _normalize_company_key(str(route.get("companyKey", "")))
    if not route_id or not company_key:
        raise ValueError("노선 id와 companyKey가 필요합니다.")
    enriched = (
        apply_road_geometry_to_route(route)
        if densify_geometry
        else dict(route)
    )
    now = datetime.utcnow()
    row = db.get(CommuteRouteRow, route_id)
    active = bool(enriched.get("active", True))
    payload = json.dumps(enriched, ensure_ascii=False)
    if row is None:
        row = CommuteRouteRow(
            id=route_id,
            company_key=company_key,
            route_json=payload,
            active=active,
            updated_at=now,
        )
        db.add(row)
    else:
        if _normalize_company_key(row.company_key) != company_key:
            raise ValueError("다른 회사의 노선은 수정할 수 없습니다.")
        row.route_json = payload
        row.active = active
        row.updated_at = now
    db.commit()
    db.refresh(row)
    return _route_row_to_dict(row)


def refresh_route_geometry(db: Session, *, route_id: str, company_key: str) -> dict | None:
    """Recompute road-following polylinePoints for an existing route."""
    row = db.get(CommuteRouteRow, route_id.strip())
    if row is None:
        return None
    if _normalize_company_key(row.company_key) != _normalize_company_key(company_key):
        raise ValueError("다른 회사의 노선은 수정할 수 없습니다.")
    data = _parse_route_json(row.route_json)
    data.setdefault("id", row.id)
    data.setdefault("companyKey", row.company_key)
    return upsert_commute_route(db, route=data, densify_geometry=True)


def deactivate_commute_route(
    db: Session,
    *,
    company_key: str,
    route_id: str,
) -> dict | None:
    row = db.get(CommuteRouteRow, route_id.strip())
    if row is None:
        return None
    if _normalize_company_key(row.company_key) != _normalize_company_key(company_key):
        raise ValueError("다른 회사의 노선은 수정할 수 없습니다.")
    row.active = False
    row.updated_at = datetime.utcnow()
    data = _parse_route_json(row.route_json)
    data["active"] = False
    row.route_json = json.dumps(data, ensure_ascii=False)
    db.commit()
    db.refresh(row)
    return _route_row_to_dict(row)


def delete_commute_route(
    db: Session,
    *,
    company_key: str,
    route_id: str,
) -> bool:
    row = db.get(CommuteRouteRow, route_id.strip())
    if row is None:
        return False
    if _normalize_company_key(row.company_key) != _normalize_company_key(company_key):
        raise ValueError("다른 회사의 노선은 삭제할 수 없습니다.")
    db.delete(row)
    db.commit()
    return True


def offer_route_share(
    db: Session,
    *,
    seeker_email: str,
    application_id: str,
    company_key: str,
    company_name: str,
    route_count: int,
) -> dict:
    del route_count
    cid = _consent_id(seeker_email, company_key)
    now = datetime.utcnow()
    row = db.get(ShuttleRouteShareConsentRow, cid)
    if row is None:
        row = ShuttleRouteShareConsentRow(
            id=cid,
            seeker_email=_normalize_email(seeker_email),
            company_key=_normalize_company_key(company_key),
            company_name=company_name.strip(),
            application_id=application_id.strip(),
            offered_at=now,
            opted_in=False,
            tower_participation_consented=False,
            updated_at=now,
        )
        db.add(row)
    else:
        if not row.application_id:
            row.application_id = application_id.strip()
        if not row.offered_at:
            row.offered_at = now
        row.company_name = company_name.strip() or row.company_name
        row.updated_at = now
    db.commit()
    db.refresh(row)
    return _consent_row_to_dict(row)


def list_consents_for_seeker(db: Session, *, email: str) -> list[dict]:
    normalized = _normalize_email(email)
    rows = (
        db.query(ShuttleRouteShareConsentRow)
        .filter(ShuttleRouteShareConsentRow.seeker_email == normalized)
        .order_by(ShuttleRouteShareConsentRow.updated_at.desc())
        .all()
    )
    return [_consent_row_to_dict(row) for row in rows]


def upsert_seeker_consent(
    db: Session,
    *,
    seeker_email: str,
    company_key: str,
    opted_in: bool,
    tower_participation_consented: bool,
    route_id: str = "",
    stop_id: str = "",
    pickup_time: str = "",
) -> dict:
    cid = _consent_id(seeker_email, company_key)
    now = datetime.utcnow()
    row = db.get(ShuttleRouteShareConsentRow, cid)
    if row is None:
        row = ShuttleRouteShareConsentRow(
            id=cid,
            seeker_email=_normalize_email(seeker_email),
            company_key=_normalize_company_key(company_key),
            offered_at=now,
        )
        db.add(row)
    row.opted_in = opted_in
    row.tower_participation_consented = tower_participation_consented
    row.route_id = route_id.strip()
    row.stop_id = stop_id.strip()
    row.pickup_time = pickup_time.strip()
    row.updated_at = now
    db.commit()
    db.refresh(row)
    return _consent_row_to_dict(row)


def list_preferences_for_seeker(db: Session, *, email: str) -> list[dict]:
    normalized = _normalize_email(email)
    rows = (
        db.query(SeekerShuttlePreferenceRow)
        .filter(SeekerShuttlePreferenceRow.seeker_email == normalized)
        .order_by(SeekerShuttlePreferenceRow.updated_at.desc())
        .all()
    )
    return [_preference_row_to_dict(row) for row in rows]


def upsert_seeker_preference(
    db: Session,
    *,
    seeker_email: str,
    company_key: str,
    company_name: str,
    route_id: str,
    route_name: str,
    stop_id: str,
    stop_label: str,
    pickup_time: str,
) -> dict:
    pid = _preference_id(seeker_email, company_key)
    now = datetime.utcnow()
    row = db.get(SeekerShuttlePreferenceRow, pid)
    if row is None:
        row = SeekerShuttlePreferenceRow(
            id=pid,
            seeker_email=_normalize_email(seeker_email),
            company_key=_normalize_company_key(company_key),
        )
        db.add(row)
    row.company_name = company_name.strip()
    row.route_id = route_id.strip()
    row.route_name = route_name.strip()
    row.stop_id = stop_id.strip()
    row.stop_label = stop_label.strip()
    row.pickup_time = pickup_time.strip()
    row.updated_at = now
    db.commit()
    db.refresh(row)
    return _preference_row_to_dict(row)


def delete_seeker_preference(
    db: Session,
    *,
    seeker_email: str,
    company_key: str,
) -> bool:
    pid = _preference_id(seeker_email, company_key)
    row = db.get(SeekerShuttlePreferenceRow, pid)
    if row is None:
        return False
    db.delete(row)
    db.commit()
    return True


def admin_participants_view(db: Session) -> dict:
    rows = (
        db.query(ShuttleRouteShareConsentRow)
        .filter(ShuttleRouteShareConsentRow.opted_in.is_(True))
        .order_by(ShuttleRouteShareConsentRow.updated_at.desc())
        .limit(200)
        .all()
    )
    tower_rows = [
        r for r in rows if r.tower_participation_consented and r.route_id
    ]
    prefs = (
        db.query(SeekerShuttlePreferenceRow)
        .order_by(SeekerShuttlePreferenceRow.updated_at.desc())
        .limit(200)
        .all()
    )
    return {
        "route_share_opted_in": [_consent_row_to_dict(r) for r in rows],
        "tower_participants": [_consent_row_to_dict(r) for r in tower_rows],
        "shuttle_preferences": [_preference_row_to_dict(r) for r in prefs],
        "counts": {
            "opted_in": len(rows),
            "tower_participants": len(tower_rows),
            "preferences": len(prefs),
        },
    }
