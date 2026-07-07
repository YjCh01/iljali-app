"""QC·데모 시드 데이터 삭제 (실서비스 정리)."""

from __future__ import annotations

import json
import re
from uuid import uuid4

from sqlalchemy import delete, func, or_, select
from sqlalchemy.orm import Session

from app.job_sync_models import ChatMessageRow, JobApplicationRow, JobPostRow
from app.models import Company
from app.push_wallet_models import CompanyBonusLedgerRow, EmployerPushWalletRow
from app.qc_models import (
    AdminAuditLogRow,
    ClosedGhostPinRow,
    CompanySanctionRow,
    JobPostEntitlementRow,
    MemberSanctionHistoryRow,
    QcMemberRow,
)

QC_EMAIL_DOMAIN = "@qc.iljari.co.kr"
QC_COMPANY_KEYS = frozenset({"1000000001", "1000000002"})
_QC_SEEKER_EMAIL = re.compile(r"^seeker-\d{4}@qc\.iljari\.co\.kr$", re.IGNORECASE)


def _qc_member_filter():
    return or_(
        QcMemberRow.email.ilike(f"%{QC_EMAIL_DOMAIN}"),
        QcMemberRow.company_key.in_(QC_COMPANY_KEYS),
    )


def _qc_post_filter():
    return or_(
        JobPostRow.id.like("qc_%"),
        JobPostRow.company_key.in_(QC_COMPANY_KEYS),
        JobPostRow.posted_by_email.ilike(f"%{QC_EMAIL_DOMAIN}"),
    )


def purge_qc_data(db: Session, *, dry_run: bool = False) -> dict:
    """QC fixture 회원·공고·지원·채팅·핀·지갑·기업 레코드 삭제."""

    qc_members = list(db.scalars(select(QcMemberRow).where(_qc_member_filter())))
    qc_emails = {m.email.strip().lower() for m in qc_members if m.email}

    qc_posts = list(db.scalars(select(JobPostRow).where(_qc_post_filter())))
    qc_post_ids = {p.id for p in qc_posts}

    app_filters = [
        JobApplicationRow.id.like("qc_%"),
        JobApplicationRow.company_key.in_(QC_COMPANY_KEYS),
        JobApplicationRow.seeker_email.ilike(f"%{QC_EMAIL_DOMAIN}"),
    ]
    if qc_post_ids:
        app_filters.append(JobApplicationRow.post_id.in_(qc_post_ids))

    qc_applications = list(
        db.scalars(select(JobApplicationRow).where(or_(*app_filters)))
    )
    qc_app_ids = {a.id for a in qc_applications}

    ghost_filters = [ClosedGhostPinRow.id.like("ghost_qc_%")]
    if qc_post_ids:
        ghost_filters.append(ClosedGhostPinRow.source_post_id.in_(qc_post_ids))

    counts = {
        "qc_members": len(qc_members),
        "job_posts": len(qc_posts),
        "applications": len(qc_applications),
        "chat_messages": 0,
        "ghost_pins": 0,
        "entitlements": 0,
        "companies": 0,
        "wallets": 0,
        "bonus_ledger": 0,
        "company_sanctions": 0,
        "member_sanction_history": 0,
    }

    if qc_app_ids:
        counts["chat_messages"] = db.scalar(
            select(func.count())
            .select_from(ChatMessageRow)
            .where(ChatMessageRow.application_id.in_(qc_app_ids))
        ) or 0

    counts["ghost_pins"] = db.scalar(
        select(func.count()).select_from(ClosedGhostPinRow).where(or_(*ghost_filters))
    ) or 0

    if qc_post_ids:
        counts["entitlements"] = db.scalar(
            select(func.count())
            .select_from(JobPostEntitlementRow)
            .where(JobPostEntitlementRow.post_id.in_(qc_post_ids))
        ) or 0

    counts["companies"] = db.scalar(
        select(func.count())
        .select_from(Company)
        .where(Company.company_key.in_(QC_COMPANY_KEYS))
    ) or 0

    counts["wallets"] = db.scalar(
        select(func.count())
        .select_from(EmployerPushWalletRow)
        .where(EmployerPushWalletRow.company_key.in_(QC_COMPANY_KEYS))
    ) or 0

    counts["bonus_ledger"] = db.scalar(
        select(func.count())
        .select_from(CompanyBonusLedgerRow)
        .where(CompanyBonusLedgerRow.company_key.in_(QC_COMPANY_KEYS))
    ) or 0

    counts["company_sanctions"] = db.scalar(
        select(func.count())
        .select_from(CompanySanctionRow)
        .where(CompanySanctionRow.company_key.in_(QC_COMPANY_KEYS))
    ) or 0

    if qc_emails:
        counts["member_sanction_history"] = db.scalar(
            select(func.count())
            .select_from(MemberSanctionHistoryRow)
            .where(MemberSanctionHistoryRow.email.in_(qc_emails))
        ) or 0

    if dry_run:
        return {"dry_run": True, "counts": counts}

    if qc_app_ids:
        db.execute(
            delete(ChatMessageRow).where(
                ChatMessageRow.application_id.in_(qc_app_ids)
            )
        )

    if qc_applications:
        db.execute(
            delete(JobApplicationRow).where(JobApplicationRow.id.in_(qc_app_ids))
        )

    if ghost_filters:
        db.execute(delete(ClosedGhostPinRow).where(or_(*ghost_filters)))

    if qc_post_ids:
        db.execute(
            delete(JobPostEntitlementRow).where(
                JobPostEntitlementRow.post_id.in_(qc_post_ids)
            )
        )
        db.execute(delete(JobPostRow).where(JobPostRow.id.in_(qc_post_ids)))

    for member in qc_members:
        db.delete(member)

    db.execute(
        delete(CompanyBonusLedgerRow).where(
            CompanyBonusLedgerRow.company_key.in_(QC_COMPANY_KEYS)
        )
    )
    db.execute(
        delete(EmployerPushWalletRow).where(
            EmployerPushWalletRow.company_key.in_(QC_COMPANY_KEYS)
        )
    )
    db.execute(delete(Company).where(Company.company_key.in_(QC_COMPANY_KEYS)))
    db.execute(
        delete(CompanySanctionRow).where(
            CompanySanctionRow.company_key.in_(QC_COMPANY_KEYS)
        )
    )

    if qc_emails:
        db.execute(
            delete(MemberSanctionHistoryRow).where(
                MemberSanctionHistoryRow.email.in_(qc_emails)
            )
        )

    db.add(
        AdminAuditLogRow(
            id=f"audit_{uuid4().hex[:12]}",
            action="purge.qc_data",
            target_type="system",
            target_id="qc_cleanup",
            detail_json=json.dumps(counts, ensure_ascii=False),
        )
    )
    db.commit()
    return {"ok": True, "counts": counts}
