"""제재 적용·이력·상태 — 자동(No-show) + 수동(Admin)."""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.job_sync_models import JobPostRow
from app.qc_models import (
    CompanySanctionRow,
    MemberSanctionHistoryRow,
    QcMemberRow,
)
from app.services.admin_ops_service import _audit, _member_dict
from app.services.entitlement_service import normalize_brn
from app.services.sanction_policy import (
    APPEAL_DAYS,
    TIER_MEASURES,
    policy_catalog,
    tier_for_violation,
    violation_catalog,
)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _appeal_until() -> datetime:
    return _now() + timedelta(days=APPEAL_DAYS)


def _member_kind(row: QcMemberRow) -> str:
    if row.member_type in ("employer", "corporate"):
        return "employer"
    return "seeker"


def _restrictions(row: QcMemberRow) -> dict:
    raw = getattr(row, "sanction_restrictions_json", "") or ""
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        return {}


def _save_restrictions(row: QcMemberRow, data: dict) -> None:
    row.sanction_restrictions_json = json.dumps(data, ensure_ascii=False)


def _history_row(
    *,
    email: str,
    member_kind: str,
    tier: str,
    violation_code: str,
    reason: str,
    measures: dict,
    source: str,
    company_key: str = "",
    appeal_until: datetime | None = None,
) -> MemberSanctionHistoryRow:
    return MemberSanctionHistoryRow(
        id=f"san_{uuid4().hex[:12]}",
        email=email.strip().lower(),
        company_key=company_key,
        member_kind=member_kind,
        tier=tier,
        violation_code=violation_code,
        reason=reason,
        measures_json=json.dumps(measures, ensure_ascii=False),
        source=source,
        appeal_until=appeal_until,
        created_at=_now(),
    )


def _get_or_create_member(db: Session, email: str, member_kind: str) -> QcMemberRow:
    normalized = email.strip().lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == normalized).first()
    if row is None:
        default_type = "employer" if member_kind == "employer" else "seeker"
        row = QcMemberRow(
            id=f"qc_{uuid4().hex[:12]}",
            email=normalized,
            display_name=normalized.split("@", 1)[0],
            member_type=default_type,
            created_at=_now(),
        )
        db.add(row)
    return row


def _get_or_create_company_sanction(db: Session, company_key: str) -> CompanySanctionRow:
    brn = normalize_brn(company_key)
    row = db.get(CompanySanctionRow, brn)
    if row is None:
        row = CompanySanctionRow(company_key=brn)
        db.add(row)
    return row


def _apply_tier_measures(
    row: QcMemberRow,
    *,
    member_kind: str,
    tier: str,
    days: int | None,
    permanent: bool,
) -> dict:
    measures_cfg = TIER_MEASURES[member_kind][tier]
    restrictions = _restrictions(row)
    applied: dict = {"tier": tier, "member_kind": member_kind}

    row.sanction_tier = tier
    row.appeal_until = _appeal_until()

    if tier in ("caution", "warning"):
        row.warning_count = (row.warning_count or 0) + measures_cfg.get(
            "warning_increment", 1
        )
        row.is_suspended = False
        row.is_permanently_banned = False
        if measures_cfg.get("internal_alert"):
            restrictions["internal_alert"] = True
        if measures_cfg.get("education_popup"):
            restrictions["education_popup"] = True
        if days_limit := measures_cfg.get("job_exposure_limit_days"):
            restrictions["job_exposure_limit_until"] = (
                _now() + timedelta(days=days_limit)
            ).isoformat()
        if apply_days := measures_cfg.get("apply_restriction_days"):
            restrictions["apply_restriction_until"] = (
                _now() + timedelta(days=apply_days)
            ).isoformat()
        if measures_cfg.get("push_limit"):
            restrictions["push_limit"] = True
        if measures_cfg.get("vault_limit"):
            restrictions["vault_limit"] = True
        if measures_cfg.get("admin_review_required"):
            row.admin_review_required = True
        row.sanction_until = None
        applied["warning_count"] = row.warning_count
        applied.update({k: v for k, v in measures_cfg.items() if k != "warning_increment"})

        threshold = measures_cfg.get("escalate_after_warnings")
        if threshold and row.warning_count >= threshold and tier == "caution":
            # 누적 주의 → 경고 승격 (내부 자동)
            return _apply_tier_measures(
                row,
                member_kind=member_kind,
                tier="warning",
                days=None,
                permanent=False,
            )
    elif tier == "suspension":
        row.is_suspended = True
        row.is_permanently_banned = permanent
        if permanent:
            row.sanction_until = None
            row.sanction_reason = "영구 이용 제한"
        else:
            suspend_days = days or measures_cfg.get("default_days") or 30
            row.sanction_until = _now() + timedelta(days=suspend_days)
            row.sanction_reason = f"{suspend_days}일 이용 제한"
        if measures_cfg.get("hide_all_posts"):
            restrictions["hide_all_posts"] = True
        if measures_cfg.get("no_refund"):
            restrictions["no_refund"] = True
        applied["suspend_days"] = None if permanent else days
        applied["permanent"] = permanent

    _save_restrictions(row, restrictions)
    applied["restrictions"] = restrictions
    applied["appeal_until"] = row.appeal_until.isoformat() if row.appeal_until else None
    return applied


def _apply_company_measures(
    db: Session,
    company_key: str,
    *,
    member_kind: str,
    tier: str,
    days: int | None,
    permanent: bool,
) -> dict:
    if not company_key:
        return {}
    row = _get_or_create_company_sanction(db, company_key)
    measures_cfg = TIER_MEASURES[member_kind][tier]
    restrictions: dict = {}
    try:
        restrictions = json.loads(row.restrictions_json or "{}")
    except json.JSONDecodeError:
        restrictions = {}

    row.sanction_tier = tier
    row.appeal_until = _appeal_until()
    row.warning_count = (row.warning_count or 0) + measures_cfg.get("warning_increment", 0)

    if tier == "suspension":
        row.is_suspended = True
        if permanent:
            row.sanction_until = None
        else:
            suspend_days = days or measures_cfg.get("default_days") or 30
            row.sanction_until = _now() + timedelta(days=suspend_days)
        if measures_cfg.get("hide_all_posts"):
            restrictions["hide_all_posts"] = True
            _hide_company_posts(db, company_key)
    elif tier == "warning":
        row.admin_review_required = True
        if limit := measures_cfg.get("job_exposure_limit_days"):
            restrictions["job_exposure_limit_until"] = (
                _now() + timedelta(days=limit)
            ).isoformat()
    elif tier == "caution":
        if limit := measures_cfg.get("job_exposure_limit_days"):
            restrictions["job_exposure_limit_until"] = (
                _now() + timedelta(days=limit)
            ).isoformat()

    row.restrictions_json = json.dumps(restrictions, ensure_ascii=False)
    return {"company_key": row.company_key, "tier": tier, "restrictions": restrictions}


def _hide_company_posts(db: Session, company_key: str) -> int:
    brn = normalize_brn(company_key)
    rows = (
        db.query(JobPostRow)
        .filter(JobPostRow.company_key == brn)
        .filter(JobPostRow.status != "hidden")
        .all()
    )
    for row in rows:
        row.status = "hidden"
        row.updated_at = _now()
    return len(rows)


def apply_policy_sanction(
    db: Session,
    *,
    email: str,
    member_kind: str,
    violation_code: str,
    reason: str = "",
    days: int | None = None,
    permanent: bool = False,
    source: str = "admin",
    company_key: str | None = None,
) -> dict:
    tier = tier_for_violation(member_kind, violation_code)
    catalog = violation_catalog(member_kind)
    violation = catalog[violation_code]
    if tier == "suspension" and days is None and not permanent:
        permanent = bool(violation.get("permanent_default"))
        if not permanent:
            days = violation.get("default_days")

    row = _get_or_create_member(db, email, member_kind)
    if company_key:
        row.company_key = normalize_brn(company_key)
    elif row.company_key:
        company_key = row.company_key

    applied = _apply_tier_measures(
        row,
        member_kind=member_kind,
        tier=tier,
        days=days,
        permanent=permanent,
    )
    company_applied = {}
    if member_kind == "employer" and company_key:
        company_applied = _apply_company_measures(
            db,
            company_key,
            member_kind=member_kind,
            tier=tier,
            days=days,
            permanent=permanent,
        )

    detail_reason = reason or violation.get("label", violation_code)
    row.sanction_reason = detail_reason

    history = _history_row(
        email=row.email,
        member_kind=member_kind,
        tier=tier,
        violation_code=violation_code,
        reason=detail_reason,
        measures={**applied, "company": company_applied},
        source=source,
        company_key=company_key or "",
        appeal_until=row.appeal_until,
    )
    db.add(history)

    _audit(
        db,
        action=f"sanction.{tier}",
        target_type=member_kind,
        target_id=row.email,
        detail={
            "violation_code": violation_code,
            "reason": detail_reason,
            "days": days,
            "permanent": permanent,
            "source": source,
        },
    )
    db.commit()
    db.refresh(row)
    return {
        "member": sanction_status(db, row.email),
        "applied": applied,
        "company": company_applied,
        "history_id": history.id,
    }


def lift_sanction(db: Session, *, email: str, reason: str = "") -> dict:
    normalized = email.strip().lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == normalized).first()
    if row is None:
        raise ValueError("member not found")

    row.is_suspended = False
    row.is_permanently_banned = False
    row.sanction_reason = ""
    row.sanction_until = None
    row.sanction_tier = ""
    row.warning_count = 0
    row.admin_review_required = False
    row.appeal_until = None
    _save_restrictions(row, {})

    if row.company_key:
        company = db.get(CompanySanctionRow, normalize_brn(row.company_key))
        if company:
            company.is_suspended = False
            company.sanction_until = None
            company.sanction_tier = ""
            company.warning_count = 0
            company.admin_review_required = False
            company.restrictions_json = "{}"

    db.add(
        _history_row(
            email=normalized,
            member_kind=_member_kind(row),
            tier="lift",
            violation_code="lift",
            reason=reason or "제재 해제",
            measures={},
            source="admin",
            company_key=row.company_key or "",
        )
    )
    _audit(
        db,
        action="sanction.lift",
        target_type=_member_kind(row),
        target_id=normalized,
        detail={"reason": reason},
    )
    db.commit()
    db.refresh(row)
    return sanction_status(db, normalized)


def sanction_status(db: Session, email: str) -> dict | None:
    normalized = email.strip().lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == normalized).first()
    if row is None:
        return None

    if row.sanction_until and row.sanction_until < _now():
        row.is_suspended = False
        row.sanction_until = None
        db.commit()

    kind = _member_kind(row)
    status = _member_dict(row)
    status["member_kind"] = kind
    status["sanction_tier"] = row.sanction_tier or ""
    status["warning_count"] = row.warning_count or 0
    status["restrictions"] = _restrictions(row)
    status["admin_review_required"] = bool(row.admin_review_required)
    status["appeal_until"] = (
        row.appeal_until.isoformat() if row.appeal_until else None
    )

    if row.company_key:
        company = db.get(CompanySanctionRow, normalize_brn(row.company_key))
        if company:
            status["company_sanction"] = {
                "company_key": company.company_key,
                "sanction_tier": company.sanction_tier,
                "warning_count": company.warning_count,
                "admin_review_required": company.admin_review_required,
                "restrictions": json.loads(company.restrictions_json or "{}"),
                "appeal_until": company.appeal_until.isoformat()
                if company.appeal_until
                else None,
            }
    return status


def list_sanction_history(
    db: Session, *, email: str, limit: int = 20
) -> list[dict]:
    normalized = email.strip().lower()
    rows = (
        db.query(MemberSanctionHistoryRow)
        .filter(MemberSanctionHistoryRow.email == normalized)
        .order_by(MemberSanctionHistoryRow.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": r.id,
            "tier": r.tier,
            "violation_code": r.violation_code,
            "reason": r.reason,
            "source": r.source,
            "measures_json": r.measures_json,
            "appeal_until": r.appeal_until.isoformat() if r.appeal_until else None,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


def company_exposure_restricted(db: Session, company_key: str) -> bool:
    """기업 공고 지도 노출 제한(주의·경고) 여부."""
    if not company_key:
        return False
    brn = normalize_brn(company_key)
    row = db.get(CompanySanctionRow, brn)
    if row is None:
        return False
    try:
        restrictions = json.loads(row.restrictions_json or "{}")
    except json.JSONDecodeError:
        restrictions = {}
    until_raw = restrictions.get("job_exposure_limit_until")
    if not until_raw:
        return False
    until = datetime.fromisoformat(str(until_raw).replace("Z", "+00:00"))
    if until.tzinfo is not None:
        until = until.replace(tzinfo=None)
    return _now() < until


def map_entitlements_for_company(
    db: Session,
    *,
    company_key: str,
    recruitment_pin_active: bool,
    shuttle_exposure_active: bool,
    map_pin_tier: str,
) -> dict:
    if company_exposure_restricted(db, company_key):
        return {
            "recruitment_pin_active": False,
            "shuttle_exposure_active": False,
            "map_pin_tier": "",
            "exposure_limited": True,
        }
    return {
        "recruitment_pin_active": recruitment_pin_active,
        "shuttle_exposure_active": shuttle_exposure_active,
        "map_pin_tier": map_pin_tier,
        "exposure_limited": False,
    }


def member_sanction_self_view(db: Session, *, email: str) -> dict:
    """본인 제재 상태 + 이력 (관리자 전용 필드 제외)."""
    normalized = email.strip().lower()
    status = sanction_status(db, normalized)
    history = list_sanction_history(db, email=normalized, limit=30)
    return {
        "status": status,
        "history": [
            {
                "id": h["id"],
                "tier": h["tier"],
                "violation_code": h["violation_code"],
                "reason": h["reason"],
                "source": h["source"],
                "appeal_until": h["appeal_until"],
                "created_at": h["created_at"],
            }
            for h in history
        ],
    }


def auto_seeker_noshow_sanction(db: Session, *, email: str, streak: int) -> dict | None:
    """No-show 누적 시 자동 주의/경고."""
    if streak <= 0:
        return None
    if streak <= 2:
        code = "noshow_1_2"
    else:
        code = "repeat_noshow"
    return apply_policy_sanction(
        db,
        email=email,
        member_kind="seeker",
        violation_code=code,
        reason=f"자동: No-show {streak}회 (셔틀·근무 연동)",
        source="auto_noshow",
    )
