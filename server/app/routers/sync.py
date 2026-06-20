from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobApplicationRow, JobPostRow
from app.qc_models import JobPostEntitlementRow
from app.routers.hiring import _row_to_dict as app_to_dict
from app.routers.job_board import _row_to_dict as post_to_dict
from app.services.admin_ops_service import member_status
from app.services.entitlement_service import normalize_brn
from app.services.push_wallet_service import get_or_create_wallet, wallet_to_response

router = APIRouter(prefix="/v1/sync", tags=["sync"])


@router.get("/bootstrap")
def sync_bootstrap(
    seeker_email: str | None = Query(default=None),
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
            entitlements[row.id] = {
                "recruitment_pin_active": ent.recruitment_pin_active,
                "shuttle_exposure_active": ent.shuttle_exposure_active,
                "map_pin_tier": ent.map_pin_tier,
            }

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

    member = member_status(db, seeker_email) if seeker_email else None

    wallet = None
    if company_key:
        brn = normalize_brn(company_key)
        wallet_row = get_or_create_wallet(db, brn)
        db.commit()
        wallet = wallet_to_response(brn, wallet_row)

    return {
        "posts": post_items,
        "post_entitlements": entitlements,
        "applications": applications,
        "member_status": member,
        "wallet": wallet,
        "counts": {
            "posts": len(post_items),
            "applications": len(applications),
        },
    }
