import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from sqlalchemy.orm import Session

from app.job_sync_models import ChatMessageRow, JobApplicationRow, JobPostRow
from app.qc_models import AdminAuditLogRow, JobPostEntitlementRow, QcMemberRow
from app.services.entitlement_service import normalize_brn
from app.services.push_wallet_service import get_or_create_wallet, wallet_to_response


def _audit(
    db: Session,
    *,
    action: str,
    target_type: str,
    target_id: str,
    detail: dict | None = None,
) -> None:
    db.add(
        AdminAuditLogRow(
            id=f"audit_{uuid4().hex[:12]}",
            action=action,
            target_type=target_type,
            target_id=target_id,
            detail_json=json.dumps(detail or {}, ensure_ascii=False),
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
    )


def grant_wallet_credits(
    db: Session,
    *,
    company_key: str,
    package_credits: int,
    location_slots: int | None = None,
) -> dict:
    brn = normalize_brn(company_key)
    wallet = get_or_create_wallet(db, brn)
    slots = location_slots if location_slots is not None else package_credits
    wallet.package_credits += max(0, package_credits)
    wallet.location_slots_from_packages += max(0, slots)
    _audit(
        db,
        action="wallet.grant",
        target_type="company",
        target_id=brn,
        detail={
            "package_credits": package_credits,
            "location_slots": slots,
        },
    )
    db.commit()
    db.refresh(wallet)
    return wallet_to_response(brn, wallet)


def set_member_sanction(
    db: Session,
    *,
    email: str,
    action: str,
    reason: str = "",
    days: int | None = None,
) -> dict:
    normalized = email.strip().lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == normalized).first()
    if row is None:
        row = QcMemberRow(
            id=f"qc_{uuid4().hex[:12]}",
            email=normalized,
            display_name=normalized.split("@", 1)[0],
            member_type="seeker",
            created_at=datetime.now(timezone.utc).replace(tzinfo=None),
        )
        db.add(row)

    until = None
    if action == "lift":
        row.is_suspended = False
        row.is_permanently_banned = False
        row.sanction_reason = ""
        row.sanction_until = None
    elif action == "permanent_ban":
        row.is_permanently_banned = True
        row.is_suspended = True
        row.sanction_reason = reason or "영구 이용 제한"
        row.sanction_until = None
    elif action == "suspend":
        row.is_suspended = True
        row.is_permanently_banned = False
        row.sanction_reason = reason or "이용 제한"
        if days is not None and days > 0:
            until = datetime.now(timezone.utc).replace(tzinfo=None) + timedelta(days=days)
            row.sanction_until = until
        else:
            row.sanction_until = None
    else:
        raise ValueError(f"unknown sanction action: {action}")

    _audit(
        db,
        action=f"member.{action}",
        target_type="member",
        target_id=normalized,
        detail={"reason": reason, "days": days},
    )
    db.commit()
    db.refresh(row)
    return _member_dict(row)


def _member_dict(row: QcMemberRow) -> dict:
    return {
        "id": row.id,
        "email": row.email,
        "display_name": row.display_name,
        "member_type": row.member_type,
        "company_key": row.company_key,
        "company_name": row.company_name,
        "is_suspended": row.is_suspended,
        "is_permanently_banned": row.is_permanently_banned,
        "sanction_reason": row.sanction_reason,
        "sanction_until": row.sanction_until.isoformat() if row.sanction_until else None,
    }


def upsert_job_pin_entitlement(
    db: Session,
    *,
    post_id: str,
    recruitment_pin_active: bool,
    map_pin_tier: str | None = None,
) -> dict:
    row = db.get(JobPostEntitlementRow, post_id)
    if row is None:
        row = JobPostEntitlementRow(post_id=post_id)
        db.add(row)
    row.recruitment_pin_active = recruitment_pin_active
    if map_pin_tier is not None:
        row.map_pin_tier = map_pin_tier
    elif recruitment_pin_active and not row.map_pin_tier:
        row.map_pin_tier = "packageActive"
    row.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    _audit(
        db,
        action="entitlement.job_pin",
        target_type="job_post",
        target_id=post_id,
        detail={
            "recruitment_pin_active": recruitment_pin_active,
            "map_pin_tier": row.map_pin_tier,
        },
    )
    db.commit()
    db.refresh(row)
    return _entitlement_dict(row)


def upsert_shuttle_entitlement(
    db: Session,
    *,
    post_id: str,
    shuttle_exposure_active: bool,
) -> dict:
    row = db.get(JobPostEntitlementRow, post_id)
    if row is None:
        row = JobPostEntitlementRow(post_id=post_id)
        db.add(row)
    row.shuttle_exposure_active = shuttle_exposure_active
    row.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    _audit(
        db,
        action="entitlement.shuttle",
        target_type="job_post",
        target_id=post_id,
        detail={"shuttle_exposure_active": shuttle_exposure_active},
    )
    db.commit()
    db.refresh(row)
    return _entitlement_dict(row)


def _entitlement_dict(row: JobPostEntitlementRow) -> dict:
    return {
        "post_id": row.post_id,
        "recruitment_pin_active": row.recruitment_pin_active,
        "shuttle_exposure_active": row.shuttle_exposure_active,
        "map_pin_tier": row.map_pin_tier,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def seed_seekers(db: Session, *, count: int, start_index: int = 1) -> dict:
    created = 0
    for i in range(start_index, start_index + count):
        email = f"seeker-{i:04d}@qc.iljari.co.kr"
        existing = (
            db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
        )
        if existing is not None:
            continue
        db.add(
            QcMemberRow(
                id=f"qc_seeker_{i:04d}",
                email=email,
                display_name=f"QC구직자 {i:04d}",
                member_type="seeker",
                created_at=datetime.now(timezone.utc).replace(tzinfo=None),
            )
        )
        created += 1
    _audit(
        db,
        action="seed.seekers",
        target_type="batch",
        target_id=f"{count}",
        detail={"created": created, "start_index": start_index},
    )
    db.commit()
    return {"requested": count, "created": created, "start_index": start_index}


def bulk_import_jobs(db: Session, posts: list[dict]) -> dict:
    imported = 0
    for item in posts:
        post_id = item.get("id") or f"post_{uuid4().hex[:12]}"
        if db.get(JobPostRow, post_id) is not None:
            continue
        db.add(
            JobPostRow(
                id=post_id,
                title=item.get("title") or "제목 없음",
                company_name=item.get("company_name") or "",
                company_key=normalize_brn(item.get("company_key") or ""),
                warehouse_name=item.get("warehouse_name") or "",
                hourly_wage=item.get("hourly_wage") or "",
                work_schedule=item.get("work_schedule") or "",
                summary=item.get("summary") or "",
                status=item.get("status") or "recruiting",
                created_at=datetime.now(timezone.utc).replace(tzinfo=None),
            )
        )
        ent = item.get("entitlements") or {}
        if ent:
            db.add(
                JobPostEntitlementRow(
                    post_id=post_id,
                    recruitment_pin_active=bool(ent.get("recruitment_pin_active")),
                    shuttle_exposure_active=bool(ent.get("shuttle_exposure_active")),
                    map_pin_tier=str(ent.get("map_pin_tier") or ""),
                )
            )
        imported += 1
    _audit(
        db,
        action="jobs.bulk_import",
        target_type="batch",
        target_id=str(len(posts)),
        detail={"imported": imported},
    )
    db.commit()
    return {"submitted": len(posts), "imported": imported}


def distribute_applications(
    db: Session,
    *,
    post_id: str,
    max_applications: int = 50,
    status: str = "applied",
) -> dict:
    post = db.get(JobPostRow, post_id)
    if post is None:
        raise ValueError("post not found")

    seekers = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.member_type == "seeker")
        .filter(QcMemberRow.is_permanently_banned.is_(False))
        .order_by(QcMemberRow.email)
        .limit(max_applications)
        .all()
    )
    created = 0
    for seeker in seekers:
        existing = (
            db.query(JobApplicationRow)
            .filter(JobApplicationRow.post_id == post_id)
            .filter(JobApplicationRow.seeker_email == seeker.email)
            .first()
        )
        if existing is not None:
            continue
        app_id = f"app_{uuid4().hex[:12]}"
        db.add(
            JobApplicationRow(
                id=app_id,
                post_id=post_id,
                post_title=post.title,
                company_name=post.company_name,
                company_key=post.company_key,
                seeker_email=seeker.email,
                seeker_name=seeker.display_name,
                status=status,
                work_schedule=post.work_schedule,
                applied_at=datetime.now(timezone.utc).replace(tzinfo=None),
            )
        )
        if created < 5:
            db.add(
                ChatMessageRow(
                    id=f"chat_{uuid4().hex[:12]}",
                    application_id=app_id,
                    sender_role="seeker",
                    sender_name=seeker.display_name,
                    body="안녕하세요, 지원했습니다.",
                    message_type="text",
                    sent_at=datetime.now(timezone.utc).replace(tzinfo=None),
                )
            )
        created += 1

    _audit(
        db,
        action="scenario.applications",
        target_type="job_post",
        target_id=post_id,
        detail={"created": created, "max": max_applications},
    )
    db.commit()
    return {"post_id": post_id, "applications_created": created}


def member_status(db: Session, email: str) -> dict | None:
    normalized = email.strip().lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == normalized).first()
    if row is None:
        return None
    if row.sanction_until and row.sanction_until < datetime.utcnow():
        row.is_suspended = False
        row.sanction_until = None
        db.commit()
    return _member_dict(row)


def list_audit_logs(db: Session, *, limit: int = 50) -> list[dict]:
    rows = (
        db.query(AdminAuditLogRow)
        .order_by(AdminAuditLogRow.created_at.desc())
        .limit(limit)
        .all()
    )
    return [
        {
            "id": r.id,
            "action": r.action,
            "target_type": r.target_type,
            "target_id": r.target_id,
            "detail_json": r.detail_json,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]
