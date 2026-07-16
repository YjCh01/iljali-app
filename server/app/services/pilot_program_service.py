"""파일럿 프로그램 — 버스 위치 관제 등."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from uuid import uuid4
from zoneinfo import ZoneInfo

from sqlalchemy.orm import Session

from app.job_sync_models import JobApplicationRow
from app.pilot_models import (
    BUS_LOCATION_TOWER_KEY,
    AppPilotProgramRow,
    BusLocationTowerSessionRow,
    ShuttleOfficerRequestRow,
)
from app.qc_models import QcMemberRow
from app.services.admin_ops_service import _audit
from app.services.entitlement_service import normalize_brn
from app.services.phone_verify_service import normalize_phone


def _normalize_email(email: str) -> str:
    return email.strip().lower()


def _today_kst() -> str:
    return datetime.now(ZoneInfo("Asia/Seoul")).date().isoformat()


def _now_kst() -> datetime:
    return datetime.now(ZoneInfo("Asia/Seoul"))


_WORK_START_RE = re.compile(r"^(\d{1,2}):(\d{2})$")


def _normalize_work_start_time(raw: str) -> str:
    text = raw.strip()
    if not text:
        return ""
    match = _WORK_START_RE.match(text)
    if match is None:
        raise ValueError("근무 시작시간은 HH:MM 형식으로 입력해 주세요.")
    hour = int(match.group(1))
    minute = int(match.group(2))
    if hour > 23 or minute > 59:
        raise ValueError("근무 시작시간이 올바르지 않습니다.")
    return f"{hour:02d}:{minute:02d}"


def _work_start_datetime_kst(service_date: str, work_start_time: str) -> datetime | None:
    normalized = _normalize_work_start_time(work_start_time)
    if not normalized:
        return None
    hour, minute = normalized.split(":")
    return datetime.fromisoformat(f"{service_date}T{hour}:{minute}:00").replace(
        tzinfo=ZoneInfo("Asia/Seoul")
    )


def _effective_work_start_time(
    program: AppPilotProgramRow | None,
    session: BusLocationTowerSessionRow | None,
) -> str:
    if session is not None and session.work_start_time:
        return session.work_start_time
    if program is not None and program.work_start_time:
        return program.work_start_time
    return ""


def _apply_work_start_arrival(
    db: Session,
    *,
    program: AppPilotProgramRow,
    session: BusLocationTowerSessionRow | None,
    service_date: str,
) -> BusLocationTowerSessionRow | None:
    work_start = _effective_work_start_time(program, session)
    cutoff = _work_start_datetime_kst(service_date, work_start)
    if cutoff is None or _now_kst() < cutoff:
        return session
    if session is None:
        return None
    if not session.arrived_at_workplace:
        session.arrived_at_workplace = True
        session.active = False
        session.stopped_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.commit()
    return session


def _tracking_blocked_by_work_start(
    program: AppPilotProgramRow | None,
    session: BusLocationTowerSessionRow | None,
    service_date: str,
) -> bool:
    if session is not None and session.arrived_at_workplace:
        return True
    work_start = _effective_work_start_time(program, session)
    cutoff = _work_start_datetime_kst(service_date, work_start)
    return cutoff is not None and _now_kst() >= cutoff


def _normalize_company_key(company_key: str) -> str:
    normalized = normalize_brn(company_key)
    return normalized if normalized else company_key.strip()


def _program_key(company_key: str, route_id: str) -> str:
    """회사·노선별 독립 슬롯 — 고용주 자기 지정과 어드민 지정이 서로 다른 회사끼리
    덮어쓰지 않도록 program_key를 (company_key, route_id) 조합으로 만든다."""
    return f"{BUS_LOCATION_TOWER_KEY}:{_normalize_company_key(company_key)}:{route_id.strip()}"


def _seeker_location_consent(seeker: QcMemberRow | None) -> bool:
    if seeker is None or not seeker.seeker_profile_json:
        return False
    try:
        profile = json.loads(seeker.seeker_profile_json)
        return bool(profile.get("locationConsentAcceptedAt"))
    except json.JSONDecodeError:
        return False


def _route_options_for_seeker(db: Session, email: str) -> list[dict]:
    rows = (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.seeker_email == _normalize_email(email))
        .filter(JobApplicationRow.commute_route_id != "")
        .order_by(JobApplicationRow.applied_at.desc())
        .limit(20)
        .all()
    )
    seen: set[tuple[str, str, str]] = set()
    options: list[dict] = []
    for row in rows:
        key = (row.company_key or "", row.commute_route_id or "", row.shuttle_shift_date or "")
        if key in seen:
            continue
        seen.add(key)
        options.append(
            {
                "company_key": row.company_key or "",
                "company_name": row.company_name or "",
                "route_id": row.commute_route_id or "",
                "route_name": row.commute_route_name or row.commute_route_id or "",
                "shift_date": row.shuttle_shift_date or "",
                "stop_id": row.shuttle_stop_id or "",
                "stop_label": row.shuttle_stop_label or "",
                "pickup_time": row.shuttle_pickup_time or "",
                "post_title": row.post_title or "",
            }
        )
    return options


def _seeker_candidate_dict(db: Session, seeker: QcMemberRow) -> dict:
    return {
        "email": seeker.email,
        "display_name": seeker.display_name or "",
        "phone": seeker.phone or "",
        "member_type": seeker.member_type,
        "location_consent_granted": _seeker_location_consent(seeker),
        "phone_verified": bool(seeker.phone_verified_at),
        "shuttle_options": _route_options_for_seeker(db, seeker.email),
        "created_at": seeker.created_at.isoformat() if seeker.created_at else None,
    }


def get_program(db: Session, program_key: str) -> AppPilotProgramRow | None:
    return db.get(AppPilotProgramRow, program_key)


def get_or_create_program(db: Session, program_key: str) -> AppPilotProgramRow:
    row = get_program(db, program_key)
    if row is not None:
        return row
    row = AppPilotProgramRow(program_key=program_key)
    db.add(row)
    db.flush()
    return row


def search_bus_location_tower_candidates(db: Session, *, phone: str) -> dict:
    digits = normalize_phone(phone)
    if len(digits) < 4:
        raise ValueError("휴대폰 번호 4자리 이상 입력해 주세요.")

    rows = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.member_type == "seeker")
        .filter(QcMemberRow.phone.like(f"%{digits}%"))
        .order_by(QcMemberRow.email)
        .limit(20)
        .all()
    )
    return {
        "phone_query": phone.strip(),
        "phone_digits": digits,
        "candidates": [_seeker_candidate_dict(db, row) for row in rows],
        "count": len(rows),
    }


def _session_id(*, service_date: str, company_key: str, route_id: str) -> str:
    safe_route = route_id.replace("/", "_").replace(" ", "_")
    return f"busloc_{service_date}_{company_key}_{safe_route}"


def _configured(row: AppPilotProgramRow | None) -> bool:
    return bool(
        row
        and row.enabled
        and row.seeker_email
        and row.company_key
        and row.route_id
    )


def _active_session_for_program(
    db: Session,
    row: AppPilotProgramRow,
    *,
    service_date: str,
) -> BusLocationTowerSessionRow | None:
    session_id = _session_id(
        service_date=service_date,
        company_key=row.company_key,
        route_id=row.route_id,
    )
    return db.get(BusLocationTowerSessionRow, session_id)


def _matching_today_application(
    db: Session,
    *,
    email: str,
    company_key: str,
    route_id: str,
    service_date: str,
) -> JobApplicationRow | None:
    return (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.seeker_email == _normalize_email(email))
        .filter(JobApplicationRow.company_key == _normalize_company_key(company_key))
        .filter(JobApplicationRow.commute_route_id == route_id.strip())
        .filter(JobApplicationRow.shuttle_shift_date == service_date)
        .filter(JobApplicationRow.status.notin_(["withdrawn", "rejected", "cancelled"]))
        .order_by(JobApplicationRow.applied_at.desc())
        .first()
    )


def _authorized_riders(
    db: Session,
    *,
    company_key: str,
    route_id: str,
    service_date: str,
) -> list[JobApplicationRow]:
    rows = (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.company_key == _normalize_company_key(company_key))
        .filter(JobApplicationRow.commute_route_id == route_id.strip())
        .filter(JobApplicationRow.shuttle_shift_date == service_date)
        .filter(JobApplicationRow.status.notin_(["withdrawn", "rejected", "cancelled"]))
        .order_by(JobApplicationRow.applied_at.desc())
        .all()
    )
    seen: set[str] = set()
    unique: list[JobApplicationRow] = []
    for row in rows:
        if row.seeker_email in seen:
            continue
        seen.add(row.seeker_email)
        unique.append(row)
    return unique


def _session_dict(session: BusLocationTowerSessionRow | None) -> dict | None:
    if session is None:
        return None
    return {
        "id": session.id,
        "service_date": session.service_date,
        "company_key": session.company_key,
        "company_name": session.company_name,
        "route_id": session.route_id,
        "route_name": session.route_name,
        "driver_email": session.driver_email,
        "driver_name": session.driver_name,
        "active": bool(session.active),
        "last_latitude": session.last_latitude,
        "last_longitude": session.last_longitude,
        "last_accuracy_m": session.last_accuracy_m,
        "last_updated_at": (
            session.last_updated_at.isoformat() if session.last_updated_at else None
        ),
        "stopped_at": session.stopped_at.isoformat() if session.stopped_at else None,
        "work_start_time": session.work_start_time or "",
        "arrived_at_workplace": bool(session.arrived_at_workplace),
    }


def upsert_bus_location_tower(
    db: Session,
    *,
    seeker_email: str,
    enabled: bool,
    company_key: str,
    route_id: str,
    company_name: str = "",
    route_name: str = "",
    note: str = "",
    work_start_time: str = "",
) -> dict:
    normalized_company_key = _normalize_company_key(company_key)
    normalized_route_id = route_id.strip()
    if not normalized_company_key or not normalized_route_id:
        raise ValueError("회사와 셔틀 노선을 함께 지정해 주세요.")

    email = _normalize_email(seeker_email)
    if enabled and email:
        seeker = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.email == email)
            .filter(QcMemberRow.member_type == "seeker")
            .first()
        )
        if seeker is None:
            raise ValueError("지정한 개인회원을 찾을 수 없습니다.")
    normalized_work_start = _normalize_work_start_time(work_start_time)
    program_key = _program_key(normalized_company_key, normalized_route_id)
    row = get_or_create_program(db, program_key)
    row.seeker_email = email
    row.company_key = normalized_company_key
    row.company_name = company_name.strip()
    row.route_id = normalized_route_id
    row.route_name = route_name.strip() or normalized_route_id
    row.enabled = enabled and bool(email)
    row.note = note.strip()
    row.work_start_time = normalized_work_start
    row.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    service_date = _today_kst()
    if _configured(row):
        session = _active_session_for_program(db, row, service_date=service_date)
        if session is not None:
            session.work_start_time = normalized_work_start
            cutoff = _work_start_datetime_kst(service_date, normalized_work_start)
            if cutoff is None or _now_kst() < cutoff:
                session.arrived_at_workplace = False
    _audit(
        db,
        action="pilot.bus_location_tower",
        target_type="program",
        target_id=program_key,
        detail={
            "seeker_email": email,
            "company_key": row.company_key,
            "route_id": row.route_id,
            "enabled": row.enabled,
            "work_start_time": normalized_work_start,
        },
    )
    db.commit()
    return bus_location_tower_admin_view(
        db, company_key=normalized_company_key, route_id=normalized_route_id
    )


def bus_location_tower_admin_view(
    db: Session, *, company_key: str, route_id: str
) -> dict:
    program_key = _program_key(company_key, route_id)
    row = get_program(db, program_key)
    if row is None:
        return {
            "program_key": program_key,
            "seeker_email": "",
            "company_key": "",
            "company_name": "",
            "route_id": "",
            "route_name": "",
            "enabled": False,
            "note": "",
            "work_start_time": "",
            "seeker_display_name": "",
            "seeker_phone": "",
            "location_consent_granted": False,
            "authorized_rider_count": 0,
            "today_session": None,
            "updated_at": None,
        }

    seeker = None
    email = _normalize_email(row.seeker_email)
    if email:
        seeker = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.email == email)
            .filter(QcMemberRow.member_type == "seeker")
            .first()
        )

    location_consent = _seeker_location_consent(seeker)
    service_date = _today_kst()
    riders = (
        _authorized_riders(
            db,
            company_key=row.company_key,
            route_id=row.route_id,
            service_date=service_date,
        )
        if _configured(row)
        else []
    )
    session = (
        _active_session_for_program(db, row, service_date=service_date)
        if _configured(row)
        else None
    )
    if _configured(row):
        session = _apply_work_start_arrival(
            db,
            program=row,
            session=session,
            service_date=service_date,
        )

    return {
        "program_key": program_key,
        "seeker_email": email,
        "company_key": row.company_key or "",
        "company_name": row.company_name or "",
        "route_id": row.route_id or "",
        "route_name": row.route_name or "",
        "enabled": bool(row.enabled),
        "note": row.note or "",
        "work_start_time": row.work_start_time or "",
        "seeker_display_name": seeker.display_name if seeker else "",
        "seeker_phone": seeker.phone if seeker else "",
        "location_consent_granted": location_consent,
        "authorized_rider_count": len(riders),
        "today_session": _session_dict(session),
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def _designated_program_for_seeker(
    db: Session, email: str
) -> AppPilotProgramRow | None:
    return (
        db.query(AppPilotProgramRow)
        .filter(AppPilotProgramRow.seeker_email == _normalize_email(email))
        .filter(AppPilotProgramRow.enabled.is_(True))
        .first()
    )


def _own_shuttle_application_today(
    db: Session, *, email: str, service_date: str
) -> JobApplicationRow | None:
    return (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.seeker_email == _normalize_email(email))
        .filter(JobApplicationRow.commute_route_id != "")
        .filter(JobApplicationRow.shuttle_shift_date == service_date)
        .filter(JobApplicationRow.status.notin_(["withdrawn", "rejected", "cancelled"]))
        .order_by(JobApplicationRow.applied_at.desc())
        .first()
    )


def bus_location_tower_status_for_seeker(db: Session, *, email: str) -> dict:
    normalized = _normalize_email(email)
    service_date = _today_kst()

    row = _designated_program_for_seeker(db, normalized)
    designated = row is not None
    if row is None:
        own_application = _own_shuttle_application_today(
            db, email=normalized, service_date=service_date
        )
        if own_application is not None:
            candidate = get_program(
                db,
                _program_key(
                    own_application.company_key, own_application.commute_route_id
                ),
            )
            if candidate is not None and _configured(candidate):
                row = candidate

    configured = _configured(row)
    rider_application = (
        _matching_today_application(
            db,
            email=normalized,
            company_key=row.company_key,
            route_id=row.route_id,
            service_date=service_date,
        )
        if configured
        else None
    )
    rider = rider_application is not None
    session = (
        _active_session_for_program(db, row, service_date=service_date)
        if configured
        else None
    )
    if configured and row is not None:
        session = _apply_work_start_arrival(
            db,
            program=row,
            session=session,
            service_date=service_date,
        )
    riders = (
        _authorized_riders(
            db,
            company_key=row.company_key,
            route_id=row.route_id,
            service_date=service_date,
        )
        if configured
        else []
    )

    seeker = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == normalized)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    location_consent = _seeker_location_consent(seeker)
    tracking_blocked = _tracking_blocked_by_work_start(row, session, service_date)
    has_location = bool(
        session
        and session.active
        and not tracking_blocked
        and session.last_latitude is not None
        and session.last_longitude is not None
    )
    role = "driver" if designated else ("rider" if rider else "inactive")
    enabled = configured and role != "inactive"
    phase = "inactive"
    if enabled and tracking_blocked:
        phase = "arrived_at_workplace"
    elif enabled and has_location:
        phase = "sharing"
    elif enabled:
        phase = "awaiting_location"
    work_start = _effective_work_start_time(row, session)

    return {
        "program": BUS_LOCATION_TOWER_KEY,
        "is_designated": designated,
        "is_authorized_rider": rider,
        "viewer_role": role,
        "enabled": enabled,
        "phase": phase,
        "title": "실시간 셔틀 위치",
        "message": (
            "오늘 같은 회사·같은 셔틀을 선택한 근무자에게만 위치가 공유됩니다."
            if enabled and not tracking_blocked
            else (
                "근무 시작시간에 통근버스가 근무지에 도착한 것으로 간주되어 "
                "위치 추적이 중지되었습니다."
                if enabled and tracking_blocked
                else ""
            )
        ),
        "location_consent_granted": location_consent,
        "company_key": row.company_key if row else "",
        "company_name": row.company_name if row else "",
        "route_id": row.route_id if row else "",
        "route_name": row.route_name if row else "",
        "service_date": service_date,
        "work_start_time": work_start,
        "tracking_stopped_reason": (
            "work_start_arrived" if tracking_blocked else ""
        ),
        "can_share_location": designated and configured and not tracking_blocked,
        "can_track_location": enabled and not tracking_blocked,
        "authorized_rider_count": len(riders),
        "rider_stop_label": rider_application.shuttle_stop_label if rider_application else "",
        "rider_pickup_time": rider_application.shuttle_pickup_time if rider_application else "",
        "today_session": _session_dict(session),
        "chat_hint": (
            "채팅 탭의 「일자리 운영팀」 공지에서 노선·일정을 조율해 주세요."
            if enabled
            else ""
        ),
    }


def update_bus_location_tower_position(
    db: Session,
    *,
    email: str,
    latitude: float,
    longitude: float,
    accuracy_m: float | None = None,
) -> dict:
    normalized = _normalize_email(email)
    row = _designated_program_for_seeker(db, normalized)
    if not _configured(row):
        raise ValueError("셔틀위치담당자만 위치를 공유할 수 있습니다.")

    service_date = _today_kst()
    session_id = _session_id(
        service_date=service_date,
        company_key=row.company_key,
        route_id=row.route_id,
    )
    session = db.get(BusLocationTowerSessionRow, session_id)
    if _tracking_blocked_by_work_start(row, session, service_date):
        raise ValueError(
            "근무 시작시간에 통근버스가 근무지에 도착한 것으로 간주되어 "
            "더 이상 위치를 공유할 수 없습니다."
        )

    driver = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == normalized)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if session is None:
        session = BusLocationTowerSessionRow(
            id=session_id,
            service_date=service_date,
            company_key=row.company_key,
            company_name=row.company_name,
            route_id=row.route_id,
            route_name=row.route_name,
            driver_email=normalized,
            driver_name=driver.display_name if driver else "",
            active=True,
            work_start_time=row.work_start_time or "",
            created_at=now,
        )
        db.add(session)
    session.company_name = row.company_name
    session.route_name = row.route_name
    session.driver_email = normalized
    session.driver_name = driver.display_name if driver else session.driver_name
    session.work_start_time = row.work_start_time or session.work_start_time
    session.active = True
    session.arrived_at_workplace = False
    session.stopped_at = None
    session.last_latitude = latitude
    session.last_longitude = longitude
    session.last_accuracy_m = accuracy_m
    session.last_updated_at = now
    _audit(
        db,
        action="pilot.bus_location_tower.location",
        target_type="session",
        target_id=session_id,
        detail={
            "driver_email": normalized,
            "company_key": row.company_key,
            "route_id": row.route_id,
        },
    )
    db.commit()
    return bus_location_tower_status_for_seeker(db, email=normalized)


def stop_bus_location_tower_today(db: Session, *, company_key: str, route_id: str) -> dict:
    row = get_program(db, _program_key(company_key, route_id))
    if not _configured(row):
        return bus_location_tower_admin_view(db, company_key=company_key, route_id=route_id)
    session = _active_session_for_program(db, row, service_date=_today_kst())
    if session is not None:
        session.active = False
        session.stopped_at = datetime.now(timezone.utc).replace(tzinfo=None)
        db.commit()
    return bus_location_tower_admin_view(db, company_key=company_key, route_id=route_id)


def _request_to_dict(row: ShuttleOfficerRequestRow) -> dict:
    return {
        "id": row.id,
        "company_key": row.company_key,
        "company_name": row.company_name,
        "route_id": row.route_id,
        "route_name": row.route_name,
        "seeker_email": row.seeker_email,
        "seeker_name": row.seeker_name,
        "work_start_time": row.work_start_time,
        "note": row.note,
        "requested_by": row.requested_by,
        "status": row.status,
        "created_at": row.created_at.replace(tzinfo=timezone.utc).isoformat()
        if row.created_at
        else None,
        "reviewed_at": row.reviewed_at.replace(tzinfo=timezone.utc).isoformat()
        if row.reviewed_at
        else None,
        "reviewed_by": row.reviewed_by,
    }


def create_officer_request(
    db: Session,
    *,
    company_key: str,
    company_name: str,
    route_id: str,
    route_name: str,
    seeker_email: str,
    seeker_name: str = "",
    work_start_time: str = "",
    note: str = "",
    requested_by: str = "",
) -> dict:
    """기업이 셔틀위치담당자 지정을 어드민에 승인요청 — 즉시 반영되지 않는다."""
    normalized_company_key = _normalize_company_key(company_key)
    normalized_route_id = route_id.strip()
    email = _normalize_email(seeker_email)
    if not normalized_company_key or not normalized_route_id or not email:
        raise ValueError("회사·노선·담당자 이메일이 모두 필요합니다.")

    seeker = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    if seeker is None:
        raise ValueError("지정한 개인회원을 찾을 수 없습니다.")

    row = ShuttleOfficerRequestRow(
        id=f"sor_{uuid4().hex[:12]}",
        company_key=normalized_company_key,
        company_name=company_name.strip(),
        route_id=normalized_route_id,
        route_name=route_name.strip() or normalized_route_id,
        seeker_email=email,
        seeker_name=seeker_name.strip() or seeker.display_name or "",
        work_start_time=_normalize_work_start_time(work_start_time),
        note=note.strip(),
        requested_by=requested_by.strip(),
        status="pending",
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _request_to_dict(row)


def list_officer_requests_for_company(db: Session, *, company_key: str) -> list[dict]:
    rows = (
        db.query(ShuttleOfficerRequestRow)
        .filter(
            ShuttleOfficerRequestRow.company_key
            == _normalize_company_key(company_key)
        )
        .order_by(ShuttleOfficerRequestRow.created_at.desc())
        .all()
    )
    return [_request_to_dict(r) for r in rows]


def list_pending_officer_requests(db: Session) -> list[dict]:
    rows = (
        db.query(ShuttleOfficerRequestRow)
        .filter(ShuttleOfficerRequestRow.status == "pending")
        .order_by(ShuttleOfficerRequestRow.created_at.asc())
        .all()
    )
    return [_request_to_dict(r) for r in rows]


def approve_officer_request(
    db: Session, *, request_id: str, reviewed_by: str = ""
) -> dict:
    row = db.get(ShuttleOfficerRequestRow, request_id)
    if row is None:
        raise ValueError("요청을 찾을 수 없습니다.")
    if row.status != "pending":
        raise ValueError("이미 처리된 요청입니다.")

    upsert_bus_location_tower(
        db,
        seeker_email=row.seeker_email,
        enabled=True,
        company_key=row.company_key,
        route_id=row.route_id,
        company_name=row.company_name,
        route_name=row.route_name,
        note=row.note,
        work_start_time=row.work_start_time,
    )

    row.status = "approved"
    row.reviewed_at = datetime.now(timezone.utc).replace(tzinfo=None)
    row.reviewed_by = reviewed_by.strip()
    db.commit()
    db.refresh(row)
    return _request_to_dict(row)


def reject_officer_request(
    db: Session, *, request_id: str, reviewed_by: str = ""
) -> dict:
    row = db.get(ShuttleOfficerRequestRow, request_id)
    if row is None:
        raise ValueError("요청을 찾을 수 없습니다.")
    if row.status != "pending":
        raise ValueError("이미 처리된 요청입니다.")

    row.status = "rejected"
    row.reviewed_at = datetime.now(timezone.utc).replace(tzinfo=None)
    row.reviewed_by = reviewed_by.strip()
    db.commit()
    db.refresh(row)
    return _request_to_dict(row)
