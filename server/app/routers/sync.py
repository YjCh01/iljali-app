from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobApplicationRow, JobPostRow
from app.qc_models import JobPostEntitlementRow
from app.routers.hiring import _row_to_dict as app_to_dict
from app.routers.job_board import _row_to_dict as post_to_dict
from app.services.entitlement_service import normalize_brn
from app.services.ghost_pin_service import list_ghost_pins
from app.services.push_wallet_service import get_or_create_wallet, wallet_to_response
from app.services.sanction_service import (
    map_entitlements_for_company,
    member_sanction_self_view,
    sanction_status,
)

router = APIRouter(prefix="/v1/sync", tags=["sync"])


@router.get("/bootstrap")
def sync_bootstrap(
    seeker_email: str | None = Query(default=None),
    member_email: str | None = Query(default=None),
    company_key: str | None = Query(default=None),
    db: Session = Depends(get_db),
):
    posts = db.query(JobPostRow).order_by(JobPostRow.created_at.desc()).all()
    post_items = []
    entitlements: dict[str, dict] = {}
    for row in posts:
        post_items.append(post_to_dict(row))
        ent = db.get(JobPostEntitlementRow, row.id)
        if ent is not None:
            entitlements[row.id] = map_entitlements_for_company(
                db,
                company_key=row.company_key or "",
                recruitment_pin_active=ent.recruitment_pin_active,
                shuttle_exposure_active=ent.shuttle_exposure_active,
                map_pin_tier=ent.map_pin_tier or "",
            )

    app_query = db.query(JobApplicationRow)
    if seeker_email:
        app_query = app_query.filter(
            JobApplicationRow.seeker_email == seeker_email.strip().lower()
        )
    if company_key:
        app_query = app_query.filter(
            JobApplicationRow.company_key == normalize_brn(company_key)
        )
    applications = [
        app_to_dict(r)
        for r in app_query.order_by(JobApplicationRow.applied_at.desc()).all()
    ]

    resolved_email = (member_email or seeker_email or "").strip().lower()
    member = sanction_status(db, resolved_email) if resolved_email else None

    wallet = None
    if company_key:
        brn = normalize_brn(company_key)
        wallet_row = get_or_create_wallet(db, brn)
        db.commit()
        wallet = wallet_to_response(brn, wallet_row)

    ghost_list = list_ghost_pins(db)
    return {
        "posts": post_items,
        "post_entitlements": entitlements,
        "ghost_pins": ghost_list,
        "applications": applications,
        "member_status": member,
        "wallet": wallet,
        "counts": {
            "posts": len(post_items),
            "applications": len(applications),
            "ghost_pins": len(ghost_list),
        },
    }


@router.get("/member/sanction")
def sync_member_sanction(
    email: str = Query(..., min_length=3),
    db: Session = Depends(get_db),
):
    """본인 제재 상태·이력 (이메일 일치 시에만)."""
    return member_sanction_self_view(db, email=email)
