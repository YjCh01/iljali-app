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
        "phone": row.phone,
        "org_role": row.org_role,
        "branch_name": row.branch_name,
        "department": row.department,
        "handler_code": row.handler_code,
        "is_suspended": row.is_suspended,
        "is_permanently_banned": row.is_permanently_banned,
        "sanction_tier": row.sanction_tier or "",
        "warning_count": row.warning_count or 0,
        "sanction_reason": row.sanction_reason,
        "sanction_until": row.sanction_until.isoformat() if row.sanction_until else None,
        "admin_review_required": bool(row.admin_review_required),
        "appeal_until": row.appeal_until.isoformat() if row.appeal_until else None,
        "created_at": row.created_at.isoformat() if row.created_at else None,
    }


ORG_ROLE_LABELS = {
    "payment_authority": "결제관리자",
    "head_office_admin": "본사관리자",
    "branch_admin": "지점관리자",
    "recruiter": "채용담당자",
}

ORG_ROLE_ORDER = [
    "payment_authority",
    "head_office_admin",
    "branch_admin",
    "recruiter",
]


def _employer_query(db: Session):
    return db.query(QcMemberRow).filter(
        QcMemberRow.member_type.in_(["employer", "corporate"])
    )


def _member_search_filter(query, q: str):
    like = f"%{q.strip().lower()}%"
    digits = "".join(ch for ch in q if ch.isdigit())
    filters = [
        QcMemberRow.email.like(like),
        QcMemberRow.display_name.like(like),
        QcMemberRow.company_name.like(like),
        QcMemberRow.phone.like(like),
        QcMemberRow.branch_name.like(like),
        QcMemberRow.department.like(like),
        QcMemberRow.handler_code.like(like),
    ]
    if digits:
        filters.append(QcMemberRow.company_key.like(f"%{digits}%"))
        filters.append(QcMemberRow.phone.like(f"%{digits}%"))
    from sqlalchemy import or_

    return query.filter(or_(*filters))


def list_corporate_directory(
    db: Session,
    *,
    q: str | None = None,
    sort: str = "brn",
) -> dict:
    query = _employer_query(db)
    if q:
        query = _member_search_filter(query, q)
    rows = query.all()

    companies: dict[str, dict] = {}
    for row in rows:
        key = row.company_key or "unknown"
        bucket = companies.setdefault(
            key,
            {
                "company_key": key,
                "company_name": row.company_name or key,
                "member_count": 0,
                "earliest_joined_at": None,
                "roles": {role: [] for role in ORG_ROLE_ORDER},
            },
        )
        if row.company_name and not bucket["company_name"]:
            bucket["company_name"] = row.company_name
        member = _member_dict(row)
        member["org_role_label"] = ORG_ROLE_LABELS.get(row.org_role, row.org_role or "기타")
        role_key = row.org_role if row.org_role in ORG_ROLE_ORDER else "recruiter"
        bucket["roles"].setdefault(role_key, []).append(member)
        bucket["member_count"] += 1
        joined = row.created_at.isoformat() if row.created_at else None
        if joined and (
            bucket["earliest_joined_at"] is None
            or joined < bucket["earliest_joined_at"]
        ):
            bucket["earliest_joined_at"] = joined

    company_list = list(companies.values())
    if sort == "company_name":
        company_list.sort(key=lambda c: c["company_name"])
    elif sort == "joined":
        company_list.sort(
            key=lambda c: c["earliest_joined_at"] or "",
            reverse=True,
        )
    else:
        company_list.sort(key=lambda c: c["company_key"])

    return {
        "companies": company_list,
        "count": len(company_list),
        "member_count": len(rows),
        "sort": sort,
        "role_labels": ORG_ROLE_LABELS,
    }


def list_employer_directory(
    db: Session,
    *,
    q: str | None = None,
    sort: str = "joined",
    limit: int = 500,
) -> dict:
    query = _employer_query(db)
    if q:
        query = _member_search_filter(query, q)
    rows = query.all()

    members = []
    for row in rows:
        item = _member_dict(row)
        item["org_role_label"] = ORG_ROLE_LABELS.get(row.org_role, row.org_role or "채용담당")
        members.append(item)

    if sort == "name":
        members.sort(key=lambda m: m.get("display_name") or m.get("email") or "")
    elif sort == "company_name":
        members.sort(key=lambda m: m.get("company_name") or "")
    elif sort == "brn":
        members.sort(key=lambda m: m.get("company_key") or "")
    else:
        members.sort(
            key=lambda m: m.get("created_at") or "",
            reverse=True,
        )

    if len(members) > limit:
        members = members[:limit]

    return {
        "members": members,
        "count": len(members),
        "sort": sort,
    }


def seed_employers(db: Session) -> dict:
    samples = [
        {
            "id": "emp_pay_alpha",
            "email": "pay-alpha@qc.iljari.co.kr",
            "display_name": "박결제",
            "company_key": "1000000001",
            "company_name": "테스트기업 알파",
            "phone": "010-1000-0001",
            "org_role": "payment_authority",
            "department": "경영지원",
            "handler_code": "1001",
        },
        {
            "id": "emp_hq_alpha",
            "email": "hq-alpha@qc.iljari.co.kr",
            "display_name": "김본사",
            "company_key": "1000000001",
            "company_name": "테스트기업 알파",
            "phone": "010-1000-0002",
            "org_role": "head_office_admin",
            "department": "본사",
            "handler_code": "1002",
        },
        {
            "id": "emp_branch_alpha",
            "email": "branch-alpha@qc.iljari.co.kr",
            "display_name": "이지점",
            "company_key": "1000000001",
            "company_name": "테스트기업 알파",
            "phone": "010-1000-0003",
            "org_role": "branch_admin",
            "branch_name": "강남지점",
            "department": "강남",
            "handler_code": "1003",
        },
        {
            "id": "emp_rec_alpha",
            "email": "recruit-alpha@qc.iljari.co.kr",
            "display_name": "최채용",
            "company_key": "1000000001",
            "company_name": "테스트기업 알파",
            "phone": "010-1000-0004",
            "org_role": "recruiter",
            "department": "채용",
            "handler_code": "1004",
        },
        {
            "id": "emp_pay_beta",
            "email": "pay-beta@qc.iljari.co.kr",
            "display_name": "정결제",
            "company_key": "1000000002",
            "company_name": "테스트기업 베타",
            "phone": "010-2000-0001",
            "org_role": "payment_authority",
            "department": "재무",
            "handler_code": "2001",
        },
        {
            "id": "emp_hq_beta",
            "email": "hq-beta@qc.iljari.co.kr",
            "display_name": "한본사",
            "company_key": "1000000002",
            "company_name": "테스트기업 베타",
            "phone": "010-2000-0002",
            "org_role": "head_office_admin",
            "department": "본사",
            "handler_code": "2002",
        },
        {
            "id": "emp_branch_beta",
            "email": "branch-beta@qc.iljari.co.kr",
            "display_name": "윤지점",
            "company_key": "1000000002",
            "company_name": "테스트기업 베타",
            "phone": "010-2000-0003",
            "org_role": "branch_admin",
            "branch_name": "판교지점",
            "department": "판교",
            "handler_code": "2003",
        },
        {
            "id": "emp_rec_beta",
            "email": "recruit-beta@qc.iljari.co.kr",
            "display_name": "서채용",
            "company_key": "1000000002",
            "company_name": "테스트기업 베타",
            "phone": "010-2000-0004",
            "org_role": "recruiter",
            "department": "인사",
            "handler_code": "2004",
        },
    ]
    created = 0
    for item in samples:
        existing = (
            db.query(QcMemberRow).filter(QcMemberRow.email == item["email"]).first()
        )
        if existing is not None:
            continue
        db.add(
            QcMemberRow(
                id=item["id"],
                email=item["email"],
                display_name=item["display_name"],
                member_type="employer",
                company_key=normalize_brn(item["company_key"]),
                company_name=item["company_name"],
                phone=item.get("phone", ""),
                org_role=item.get("org_role", "recruiter"),
                branch_name=item.get("branch_name", ""),
                department=item.get("department", ""),
                handler_code=item.get("handler_code", ""),
                created_at=datetime.now(timezone.utc).replace(tzinfo=None),
            )
        )
        created += 1
    _audit(
        db,
        action="seed.employers",
        target_type="batch",
        target_id=str(len(samples)),
        detail={"created": created},
    )
    db.commit()
    return {"requested": len(samples), "created": created}


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
    updated = 0
    for item in posts:
        post_id = item.get("id") or f"post_{uuid4().hex[:12]}"
        existing = db.get(JobPostRow, post_id)
        if existing is not None:
            if item.get("posted_by_email"):
                existing.posted_by_email = item["posted_by_email"].strip().lower()
            if item.get("posted_by_name"):
                existing.posted_by_name = item["posted_by_name"]
            if item.get("view_count") is not None:
                existing.view_count = int(item["view_count"])
            if item.get("map_impression_count") is not None:
                existing.map_impression_count = int(item["map_impression_count"])
            updated += 1
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
                posted_by_email=(item.get("posted_by_email") or "").strip().lower(),
                posted_by_name=item.get("posted_by_name") or "",
                view_count=int(item.get("view_count") or 0),
                map_impression_count=int(item.get("map_impression_count") or 0),
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
        detail={"imported": imported, "updated": updated},
    )
    db.commit()
    return {"submitted": len(posts), "imported": imported, "updated": updated}


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


QC_VISUAL_APP_ID = "qc_app_alpha_seeker_0001"
QC_VISUAL_SEEKER_EMAIL = "seeker-0001@qc.iljari.co.kr"
QC_VISUAL_POST_ID = "qc_post_real_001"
QC_VISUAL_COMPANY_KEY = "1000000001"


def seed_qc_visual_scenario(db: Session) -> dict:
    """테스트기업 알파 공고 + QC구직자 0001 지원 (QC 눈검증용)."""
    post = db.get(JobPostRow, QC_VISUAL_POST_ID)
    if post is None:
        return {"ok": False, "reason": "post_missing", "post_id": QC_VISUAL_POST_ID}

    seeker = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == QC_VISUAL_SEEKER_EMAIL)
        .first()
    )
    if seeker is None:
        return {"ok": False, "reason": "seeker_missing", "email": QC_VISUAL_SEEKER_EMAIL}

    row = db.get(JobApplicationRow, QC_VISUAL_APP_ID)
    created = False
    if row is None:
        row = (
            db.query(JobApplicationRow)
            .filter(JobApplicationRow.post_id == QC_VISUAL_POST_ID)
            .filter(JobApplicationRow.seeker_email == QC_VISUAL_SEEKER_EMAIL)
            .first()
        )
    if row is None:
        row = JobApplicationRow(
            id=QC_VISUAL_APP_ID,
            post_id=QC_VISUAL_POST_ID,
            post_title=post.title,
            company_name=post.company_name,
            company_key=post.company_key,
            seeker_email=QC_VISUAL_SEEKER_EMAIL,
            seeker_name=seeker.display_name,
            status="chatting",
            work_schedule=post.work_schedule,
            applied_at=datetime.now(timezone.utc).replace(tzinfo=None)
            - timedelta(days=1),
        )
        db.add(row)
        created = True

    chat_count = (
        db.query(ChatMessageRow)
        .filter(ChatMessageRow.application_id == row.id)
        .count()
    )
    chats_created = 0
    if chat_count == 0:
        now = datetime.now(timezone.utc).replace(tzinfo=None)
        db.add(
            ChatMessageRow(
                id=f"chat_{uuid4().hex[:12]}",
                application_id=row.id,
                sender_role="seeker",
                sender_name=seeker.display_name,
                body="안녕하세요, QC구직자 0001입니다. 지원했습니다.",
                message_type="text",
                sent_at=now - timedelta(hours=3),
            )
        )
        db.add(
            ChatMessageRow(
                id=f"chat_{uuid4().hex[:12]}",
                application_id=row.id,
                sender_role="employer",
                sender_name="최채용",
                body="안녕하세요, 테스트기업 알파 채용 담당입니다.\n근무 일정 확인 부탁드립니다.",
                message_type="text",
                sent_at=now - timedelta(hours=2, minutes=40),
            )
        )
        chats_created = 2

    _audit(
        db,
        action="seed.qc_visual_scenario",
        target_type="application",
        target_id=row.id,
        detail={
            "created": created,
            "chats_created": chats_created,
            "post_id": QC_VISUAL_POST_ID,
            "seeker_email": QC_VISUAL_SEEKER_EMAIL,
        },
    )
    db.commit()
    return {
        "ok": True,
        "application_id": row.id,
        "application_created": created,
        "chats_created": chats_created,
        "post_id": QC_VISUAL_POST_ID,
        "seeker_email": QC_VISUAL_SEEKER_EMAIL,
    }


def member_status(db: Session, email: str) -> dict | None:
    from app.services.sanction_service import sanction_status

    return sanction_status(db, email)


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


_MAP_CENTER_LAT = 37.5128
_MAP_CENTER_LNG = 127.0471
_MAP_OFFSETS = [
    (0.004, 0.003),
    (-0.003, 0.005),
    (0.006, -0.004),
    (-0.005, -0.003),
]


def _map_coords(index: int) -> tuple[float, float]:
    lat_off, lng_off = _MAP_OFFSETS[index % len(_MAP_OFFSETS)]
    return _MAP_CENTER_LAT + lat_off, _MAP_CENTER_LNG + lng_off


def _resolve_poster(db: Session, post: JobPostRow) -> dict:
    email = (post.posted_by_email or "").strip().lower()
    name = post.posted_by_name or ""
    org_role = ""
    phone = ""
    if email:
        member = db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
        if member:
            name = name or member.display_name
            org_role = member.org_role or ""
            phone = member.phone or ""
    elif post.company_key:
        member = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.company_key == post.company_key)
            .filter(QcMemberRow.org_role == "recruiter")
            .order_by(QcMemberRow.created_at.asc())
            .first()
        )
        if member:
            email = member.email
            name = member.display_name
            org_role = member.org_role
            phone = member.phone or ""
    return {
        "email": email,
        "name": name or email or "미등록",
        "org_role": org_role,
        "org_role_label": ORG_ROLE_LABELS.get(org_role, org_role or "채용담당"),
        "phone": phone,
    }


def _job_map_item(db: Session, post: JobPostRow, index: int) -> dict:
    ent = db.get(JobPostEntitlementRow, post.id)
    lat, lng = _map_coords(index)
    app_count = (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.post_id == post.id)
        .count()
    )
    poster = _resolve_poster(db, post)
    return {
        "id": post.id,
        "title": post.title,
        "company_name": post.company_name,
        "company_key": post.company_key,
        "warehouse_name": post.warehouse_name,
        "hourly_wage": post.hourly_wage,
        "work_schedule": post.work_schedule,
        "summary": post.summary,
        "status": post.status,
        "latitude": lat,
        "longitude": lng,
        "application_count": app_count,
        "view_count": post.view_count or 0,
        "map_impression_count": post.map_impression_count or 0,
        "posted_by_email": poster["email"],
        "posted_by_name": poster["name"],
        "posted_by_role": poster["org_role_label"],
        "recruitment_pin_active": ent.recruitment_pin_active if ent else False,
        "shuttle_exposure_active": ent.shuttle_exposure_active if ent else False,
        "map_pin_tier": ent.map_pin_tier if ent else "",
        "created_at": post.created_at.isoformat() if post.created_at else None,
    }


def get_job_map_detail(db: Session, *, post_id: str) -> dict:
    post = db.get(JobPostRow, post_id)
    if post is None:
        raise ValueError("post not found")
    index = (
        db.query(JobPostRow)
        .filter(JobPostRow.created_at >= post.created_at)
        .count()
        if post.created_at
        else 0
    )
    item = _job_map_item(db, post, max(index - 1, 0))
    apps = (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.post_id == post_id)
        .order_by(JobApplicationRow.applied_at.desc())
        .all()
    )
    status_counts: dict[str, int] = {}
    for app in apps:
        status_counts[app.status] = status_counts.get(app.status, 0) + 1
    item["poster"] = _resolve_poster(db, post)
    item["application_count"] = len(apps)
    item["applications_by_status"] = status_counts
    item["recent_applicants"] = [
        {
            "seeker_email": a.seeker_email,
            "seeker_name": a.seeker_name,
            "status": a.status,
            "applied_at": a.applied_at.isoformat() if a.applied_at else None,
        }
        for a in apps[:10]
    ]
    return item


def list_jobs_for_map(db: Session) -> list[dict]:
    posts = (
        db.query(JobPostRow)
        .order_by(JobPostRow.created_at.desc())
        .all()
    )
    return [_job_map_item(db, post, index) for index, post in enumerate(posts)]


def list_applications_for_admin(
    db: Session,
    *,
    seeker_email: str | None = None,
    company_key: str | None = None,
    q: str | None = None,
    limit: int = 100,
) -> list[dict]:
    query = db.query(JobApplicationRow)
    if seeker_email:
        query = query.filter(
            JobApplicationRow.seeker_email == seeker_email.strip().lower()
        )
    if company_key:
        brn = normalize_brn(company_key)
        query = query.filter(JobApplicationRow.company_key == brn)
    if q:
        like = f"%{q.strip().lower()}%"
        query = query.filter(
            (JobApplicationRow.seeker_email.like(like))
            | (JobApplicationRow.seeker_name.like(like))
            | (JobApplicationRow.post_title.like(like))
            | (JobApplicationRow.company_name.like(like))
        )
    rows = query.order_by(JobApplicationRow.applied_at.desc()).limit(limit).all()
    result: list[dict] = []
    for row in rows:
        msg_count = (
            db.query(ChatMessageRow)
            .filter(ChatMessageRow.application_id == row.id)
            .count()
        )
        item = {
            "id": row.id,
            "post_id": row.post_id,
            "post_title": row.post_title,
            "company_name": row.company_name,
            "company_key": row.company_key,
            "seeker_email": row.seeker_email,
            "seeker_name": row.seeker_name,
            "status": row.status,
            "work_schedule": row.work_schedule,
            "applied_at": row.applied_at.isoformat() if row.applied_at else None,
            "message_count": msg_count,
        }
        result.append(item)
    return result


def list_chat_for_application(db: Session, *, application_id: str) -> dict:
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        raise ValueError("application not found")
    rows = (
        db.query(ChatMessageRow)
        .filter(ChatMessageRow.application_id == application_id)
        .order_by(ChatMessageRow.sent_at.asc())
        .all()
    )
    return {
        "application": {
            "id": app.id,
            "post_id": app.post_id,
            "post_title": app.post_title,
            "company_name": app.company_name,
            "company_key": app.company_key,
            "seeker_email": app.seeker_email,
            "seeker_name": app.seeker_name,
            "status": app.status,
            "applied_at": app.applied_at.isoformat() if app.applied_at else None,
        },
        "messages": [
            {
                "id": r.id,
                "application_id": r.application_id,
                "sender_role": r.sender_role,
                "sender_name": r.sender_name,
                "body": r.body,
                "message_type": r.message_type,
                "sent_at": r.sent_at.isoformat() if r.sent_at else None,
            }
            for r in rows
        ],
    }
