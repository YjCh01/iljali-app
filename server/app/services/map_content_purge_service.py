"""지도 테스트 콘텐츠 전체 삭제 — 유령핀·유령노선·공고·셔틀 노선."""

from __future__ import annotations

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.job_sync_models import ChatMessageRow, JobApplicationRow, JobPostRow
from app.qc_models import (
    ClosedGhostPinRow,
    ClosedGhostRouteRow,
    JobPostEntitlementRow,
)
from app.shuttle_models import (
    CommuteRouteRow,
    SeekerShuttlePreferenceRow,
    ShuttleRouteShareConsentRow,
)


def purge_map_content(db: Session, *, dry_run: bool = False) -> dict:
    """공고·지원·채팅·유령핀/노선·셔틀 노선·관련 선호를 전부 삭제.

    회원·지갑·기업 프로필은 유지한다.
    """

    counts = {
        "chat_messages": db.scalar(select(func.count()).select_from(ChatMessageRow))
        or 0,
        "job_applications": db.scalar(
            select(func.count()).select_from(JobApplicationRow)
        )
        or 0,
        "job_post_entitlements": db.scalar(
            select(func.count()).select_from(JobPostEntitlementRow)
        )
        or 0,
        "job_posts": db.scalar(select(func.count()).select_from(JobPostRow)) or 0,
        "closed_ghost_routes": db.scalar(
            select(func.count()).select_from(ClosedGhostRouteRow)
        )
        or 0,
        "closed_ghost_pins": db.scalar(
            select(func.count()).select_from(ClosedGhostPinRow)
        )
        or 0,
        "seeker_shuttle_preferences": db.scalar(
            select(func.count()).select_from(SeekerShuttlePreferenceRow)
        )
        or 0,
        "shuttle_route_share_consents": db.scalar(
            select(func.count()).select_from(ShuttleRouteShareConsentRow)
        )
        or 0,
        "commute_routes": db.scalar(select(func.count()).select_from(CommuteRouteRow))
        or 0,
    }

    if dry_run:
        return {"dry_run": True, "deleted": counts}

    # FK/참조 안전 순서
    db.execute(delete(ChatMessageRow))
    db.execute(delete(JobApplicationRow))
    db.execute(delete(JobPostEntitlementRow))
    db.execute(delete(JobPostRow))
    db.execute(delete(ClosedGhostRouteRow))
    db.execute(delete(ClosedGhostPinRow))
    db.execute(delete(SeekerShuttlePreferenceRow))
    db.execute(delete(ShuttleRouteShareConsentRow))
    db.execute(delete(CommuteRouteRow))
    db.commit()

    return {"dry_run": False, "deleted": counts}


def delete_job_post_admin(db: Session, *, post_id: str) -> bool:
    """어드민 — 공고 1건 + 관련 지원/채팅/엔타이틀먼트 삭제."""
    row = db.get(JobPostRow, post_id)
    if row is None:
        return False
    app_ids = list(
        db.scalars(
            select(JobApplicationRow.id).where(JobApplicationRow.post_id == post_id)
        )
    )
    if app_ids:
        db.execute(
            delete(ChatMessageRow).where(ChatMessageRow.application_id.in_(app_ids))
        )
    db.execute(delete(JobApplicationRow).where(JobApplicationRow.post_id == post_id))
    db.execute(
        delete(JobPostEntitlementRow).where(JobPostEntitlementRow.post_id == post_id)
    )
    db.execute(
        delete(ClosedGhostPinRow).where(ClosedGhostPinRow.source_post_id == post_id)
    )
    db.delete(row)
    db.commit()
    return True
