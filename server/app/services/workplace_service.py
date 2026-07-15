"""같은 물리적 근무지 식별 — resolve-or-create.

좌표(~5m)·근무지명 매칭 기준은 Flutter `ExposureSlotPolicy.coordinatesMatch`
(lib/features/corporate/domain/utils/exposure_slot_policy.dart)와 동일하게 맞춘다.
새 판정 기준을 따로 만들지 않고 기존 유령핀 억제 로직이 쓰던 기준을 그대로 재사용한다.
"""

from datetime import datetime
from uuid import uuid4

from sqlalchemy.orm import Session

from app.job_sync_models import JobPostRow, WorkplaceRow
from app.services.entitlement_service import normalize_brn

COORDINATE_EPSILON = 0.00005


def _coordinates_match(
    lat1: float | None,
    lng1: float | None,
    lat2: float | None,
    lng2: float | None,
) -> bool:
    if lat1 is None or lng1 is None or lat2 is None or lng2 is None:
        return False
    return abs(lat1 - lat2) <= COORDINATE_EPSILON and abs(lng1 - lng2) <= COORDINATE_EPSILON


def resolve_or_create_workplace(
    db: Session,
    *,
    company_key: str,
    warehouse_name: str,
    latitude: float | None,
    longitude: float | None,
) -> str | None:
    """회사 내 동일 근무지를 찾아 재사용하거나 새로 생성 — workplace_id 반환.

    근무지명·좌표가 모두 없으면 판별 근거가 없으므로 None(미할당)."""
    name = (warehouse_name or "").strip()
    if not name and latitude is None and longitude is None:
        return None

    brn = normalize_brn(company_key)
    candidates = (
        db.query(WorkplaceRow).filter(WorkplaceRow.company_key == brn).all()
    )
    for candidate in candidates:
        if _coordinates_match(latitude, longitude, candidate.latitude, candidate.longitude):
            return candidate.id
        if name and candidate.warehouse_name.strip() == name:
            return candidate.id

    workplace = WorkplaceRow(
        id=f"wp_{uuid4().hex[:12]}",
        company_key=brn,
        warehouse_name=name,
        latitude=latitude,
        longitude=longitude,
        created_at=datetime.utcnow(),
    )
    db.add(workplace)
    db.flush()
    return workplace.id


def backfill_missing_workplace_ids(db: Session) -> int:
    """workplace_id 도입 이전 공고를 회사별로 클러스터링해 1회성 할당.

    같은 resolve-or-create를 행마다 순차 호출하는 것만으로 같은 회사·같은
    근무지 행들이 자연스럽게 같은 workplace_id로 묶인다."""
    rows = (
        db.query(JobPostRow)
        .filter(JobPostRow.workplace_id.is_(None))
        .order_by(JobPostRow.created_at.asc())
        .all()
    )
    updated = 0
    for row in rows:
        workplace_id = resolve_or_create_workplace(
            db,
            company_key=row.company_key,
            warehouse_name=row.warehouse_name,
            latitude=row.workplace_latitude,
            longitude=row.workplace_longitude,
        )
        if workplace_id is not None:
            row.workplace_id = workplace_id
            updated += 1
    if updated:
        db.commit()
    return updated
