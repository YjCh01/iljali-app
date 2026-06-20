from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps.admin_auth import require_admin_api_key
from app.qc_models import QcMemberRow
from app.services.admin_ops_service import (
    bulk_import_jobs,
    distribute_applications,
    grant_wallet_credits,
    list_audit_logs,
    seed_seekers,
    set_member_sanction,
    upsert_job_pin_entitlement,
    upsert_shuttle_entitlement,
)
from app.services.entitlement_service import normalize_brn
from app.services.push_wallet_service import get_or_create_wallet, wallet_to_response

router = APIRouter(prefix="/v1/admin/ops", tags=["admin-ops"])


class WalletGrantBody(BaseModel):
    company_key: str
    package_credits: int = Field(ge=0)
    location_slots: int | None = Field(default=None, ge=0)


class MemberSanctionBody(BaseModel):
    email: str
    action: str = Field(description="suspend | permanent_ban | lift")
    reason: str = ""
    days: int | None = Field(default=None, ge=1, le=3650)


class JobPinEntitlementBody(BaseModel):
    post_id: str
    recruitment_pin_active: bool = True
    map_pin_tier: str | None = None


class ShuttleEntitlementBody(BaseModel):
    post_id: str
    shuttle_exposure_active: bool = True


class SeedSeekersBody(BaseModel):
    count: int = Field(default=1000, ge=1, le=5000)
    start_index: int = Field(default=1, ge=1)


class BulkJobsBody(BaseModel):
    posts: list[dict]


class DistributeApplicationsBody(BaseModel):
    post_id: str
    max_applications: int = Field(default=50, ge=1, le=1000)
    status: str = "applied"


@router.get("/health")
def ops_health(_: str = Depends(require_admin_api_key)):
    return {"status": "ok", "scope": "admin-ops"}


@router.post("/wallet/grant")
def ops_wallet_grant(
    body: WalletGrantBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return grant_wallet_credits(
        db,
        company_key=body.company_key,
        package_credits=body.package_credits,
        location_slots=body.location_slots,
    )


@router.get("/wallet/{company_key}")
def ops_wallet_get(
    company_key: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    brn = normalize_brn(company_key)
    wallet = get_or_create_wallet(db, brn)
    db.commit()
    return wallet_to_response(brn, wallet)


@router.post("/members/sanction")
def ops_member_sanction(
    body: MemberSanctionBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return set_member_sanction(
            db,
            email=body.email,
            action=body.action,
            reason=body.reason,
            days=body.days,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.get("/members")
def ops_list_members(
    q: str | None = Query(default=None),
    limit: int = Query(default=50, ge=1, le=500),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    query = db.query(QcMemberRow)
    if q:
        like = f"%{q.strip().lower()}%"
        query = query.filter(QcMemberRow.email.like(like))
    rows = query.order_by(QcMemberRow.email).limit(limit).all()
    return {
        "members": [
            {
                "email": r.email,
                "display_name": r.display_name,
                "member_type": r.member_type,
                "is_suspended": r.is_suspended,
                "is_permanently_banned": r.is_permanently_banned,
                "sanction_reason": r.sanction_reason,
            }
            for r in rows
        ],
        "count": len(rows),
    }


@router.post("/entitlements/job-pin")
def ops_job_pin(
    body: JobPinEntitlementBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return upsert_job_pin_entitlement(
        db,
        post_id=body.post_id,
        recruitment_pin_active=body.recruitment_pin_active,
        map_pin_tier=body.map_pin_tier,
    )


@router.post("/entitlements/shuttle-exposure")
def ops_shuttle_exposure(
    body: ShuttleEntitlementBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return upsert_shuttle_entitlement(
        db,
        post_id=body.post_id,
        shuttle_exposure_active=body.shuttle_exposure_active,
    )


@router.post("/seed/seekers")
def ops_seed_seekers(
    body: SeedSeekersBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return seed_seekers(db, count=body.count, start_index=body.start_index)


@router.post("/jobs/bulk")
def ops_bulk_jobs(
    body: BulkJobsBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return bulk_import_jobs(db, body.posts)


@router.post("/scenario/applications")
def ops_scenario_applications(
    body: DistributeApplicationsBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return distribute_applications(
            db,
            post_id=body.post_id,
            max_applications=body.max_applications,
            status=body.status,
        )
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get("/audit")
def ops_audit(
    limit: int = Query(default=50, ge=1, le=200),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return {"logs": list_audit_logs(db, limit=limit)}
