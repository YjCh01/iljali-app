from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.deps.admin_auth import require_admin_api_key
from app.qc_models import QcMemberRow
from app.services.admin_bulk_shuttle_import_service import bulk_import_shuttle_routes_from_excel
from app.services.admin_bulk_url_import_service import (
    bulk_import_job_urls,
    extract_urls,
    preview_job_urls,
)
from app.services.job_post_image_remirror import remirror_job_post_images
from app.services.pilot_program_service import (
    approve_officer_request,
    bus_location_tower_admin_view,
    list_pending_officer_requests,
    reject_officer_request,
    search_bus_location_tower_candidates,
    stop_bus_location_tower_today,
    upsert_bus_location_tower,
)
from app.services.shuttle_commute_service import admin_participants_view
from app.services.admin_ops_service import (
    bulk_import_jobs,
    distribute_applications,
    grant_wallet_credits,
    list_applications_for_admin,
    list_audit_logs,
    list_chat_for_application,
    list_corporate_directory,
    list_employer_directory,
    get_job_map_detail,
    list_jobs_for_map,
    seed_employers,
    seed_seekers,
    set_member_sanction,
    upsert_job_pin_entitlement,
    upsert_shuttle_entitlement,
)
from app.services.ghost_pin_service import (
    create_ghost_pin,
    delete_ghost_pin,
    list_ghost_pins,
)
from app.services.event_pin_service import (
    create_event_pin,
    delete_event_pin,
    list_event_pins,
)
from app.services.ghost_route_service import (
    create_ghost_route,
    delete_ghost_route,
    list_ghost_routes,
)
from app.services.admin_announcement_service import (
    create_announcement,
    list_announcements,
)
from app.services.admin_grant_revoke_service import revoke_admin_grants
from app.services.map_content_purge_service import (
    delete_job_post_admin,
    purge_map_content,
)
from app.services.qc_data_purge_service import purge_qc_data
from app.models import Company
from app.services.entitlement_service import get_or_create_company, normalize_brn
from app.services.push_wallet_service import get_or_create_wallet, wallet_to_response
from app.services.sanction_policy import policy_catalog
from app.services.sanction_service import (
    apply_policy_sanction,
    lift_sanction,
    list_sanction_history,
    sanction_status,
)
from app.services.workplace_mismatch_service import (
    approve_stated_workplace_post,
    list_pending_workplace_mismatch_flags,
)

router = APIRouter(prefix="/v1/admin/ops", tags=["admin-ops"])


class WalletGrantBody(BaseModel):
    company_key: str
    package_credits: int = Field(default=0, ge=0)
    shuttle_stop_credits: int = Field(default=0, ge=0)
    push_ticket_credits: int = Field(default=0, ge=0)
    location_slots: int | None = Field(default=None, ge=0)


class CompanyVerificationApproveBody(BaseModel):
    reason: str | None = None


def _corporate_member_for_brn(db: Session, brn: str) -> QcMemberRow | None:
    return (
        db.query(QcMemberRow)
        .filter(QcMemberRow.company_key == brn)
        .filter(QcMemberRow.member_type == "corporate")
        .order_by(QcMemberRow.created_at.desc())
        .first()
    )


def _company_needs_admin_approval(company: Company | None, member: QcMemberRow | None) -> bool:
    if company:
        if company.admin_review_approved:
            return False
        if company.is_suspended or company.verification_status == "rejected":
            return False
        if company.requires_admin_review:
            return True
        return company.verification_status in ("pending", "adminReviewRequired")
    return member is not None


class MemberSanctionBody(BaseModel):
    email: str
    action: str = Field(description="suspend | permanent_ban | lift")
    reason: str = ""
    days: int | None = Field(default=None, ge=1, le=3650)


class PolicySanctionBody(BaseModel):
    email: str
    member_kind: str = Field(description="employer | seeker")
    violation_code: str
    reason: str = ""
    days: int | None = Field(default=None, ge=1, le=3650)
    permanent: bool = False
    company_key: str | None = None


class JobPinEntitlementBody(BaseModel):
    post_id: str
    recruitment_pin_active: bool = True
    map_pin_tier: str | None = None


class ShuttleEntitlementBody(BaseModel):
    post_id: str
    shuttle_exposure_active: bool = True


class GhostPinCreateBody(BaseModel):
    latitude: float
    longitude: float
    label: str = ""
    source_post_id: str = ""


class EventPinCreateBody(BaseModel):
    latitude: float
    longitude: float
    title: str = ""
    body: str = ""
    kind: str = "info"
    color_hex: str = "#FF6F00"
    payload: dict = Field(default_factory=dict)
    active: bool = True


class GhostRouteStopBody(BaseModel):
    latitude: float
    longitude: float


class GhostRouteCreateBody(BaseModel):
    workplace_latitude: float
    workplace_longitude: float
    stops: list[GhostRouteStopBody] = Field(default_factory=list)
    label: str = ""


class AdminAnnouncementCreateBody(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(min_length=1)
    audience: str = Field(default="all", pattern="^(all|seeker|corporate)$")
    push_requested: bool = True


class SeedSeekersBody(BaseModel):
    count: int = Field(default=1000, ge=1, le=5000)
    start_index: int = Field(default=1, ge=1)


class BulkJobsBody(BaseModel):
    posts: list[dict]


class BulkImportUrlsBody(BaseModel):
    urls: list[str] = Field(default_factory=list)
    url_text: str = ""
    company_key: str = "5403100894"
    company_name: str = "아라컴퍼니"
    posted_by_email: str = ""
    posted_by_name: str = ""
    activate_job_pin: bool = True


class BusLocationTowerPilotBody(BaseModel):
    seeker_email: str = ""
    enabled: bool = True
    company_key: str = ""
    company_name: str = ""
    route_id: str = ""
    route_name: str = ""
    note: str = ""
    work_start_time: str = ""


class DistributeApplicationsBody(BaseModel):
    post_id: str
    max_applications: int = Field(default=50, ge=1, le=1000)
    status: str = "applied"


@router.get("/members/directory/corporate")
def ops_corporate_directory(
    q: str | None = Query(default=None),
    sort: str = Query(default="brn", description="brn | company_name | joined"),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return list_corporate_directory(db, q=q, sort=sort)


@router.get("/members/directory/employers")
def ops_employer_directory(
    q: str | None = Query(default=None),
    sort: str = Query(default="joined", description="joined | name | company_name | brn"),
    limit: int = Query(default=500, ge=1, le=1000),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return list_employer_directory(db, q=q, sort=sort, limit=limit)


@router.post("/seed/employers")
def ops_seed_employers(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return seed_employers(db)


@router.post("/purge/qc")
def ops_purge_qc_data(
    dry_run: bool = Query(default=False),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return purge_qc_data(db, dry_run=dry_run)


@router.post("/purge/map-content")
def ops_purge_map_content(
    dry_run: bool = Query(default=False),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    """유령핀·유령노선·공고·셔틀 노선 전체 삭제 (회원·지갑 유지)."""
    return purge_map_content(db, dry_run=dry_run)


@router.post("/wallet/revoke-admin-grants")
def ops_revoke_admin_grants(
    dry_run: bool = Query(default=False),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return revoke_admin_grants(db, dry_run=dry_run)


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
        shuttle_stop_credits=body.shuttle_stop_credits,
        push_ticket_credits=body.push_ticket_credits,
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
    return wallet_to_response(brn, wallet, db)


@router.get("/companies/{company_key}/verification")
def ops_company_verification(
    company_key: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    brn = normalize_brn(company_key)
    if not brn:
        raise HTTPException(status_code=400, detail="사업자등록번호를 확인해 주세요.")

    company = db.query(Company).filter(Company.company_key == brn).first()
    member = _corporate_member_for_brn(db, brn)
    if company is None and member is None:
        raise HTTPException(status_code=404, detail="등록된 기업 회원을 찾을 수 없습니다.")

    if company:
        status = company.verification_status
        company_name = company.company_name
        reason = company.admin_review_reason
        has_server_record = True
    else:
        status = "pending"
        company_name = member.company_name
        reason = "미인증 가입 — 등록증 미제출 또는 앱 로컬만 저장된 상태"
        has_server_record = False

    return {
        "company_key": brn,
        "company_name": company_name,
        "verification_status": status,
        "requires_admin_review": company.requires_admin_review if company else False,
        "admin_review_approved": company.admin_review_approved if company else False,
        "admin_review_reason": reason,
        "has_registered_member": member is not None,
        "has_server_record": has_server_record,
        "needs_admin_approval": _company_needs_admin_approval(company, member),
        "certificate_image_ref": company.certificate_image_ref if company else None,
    }


@router.post("/companies/{company_key}/approve-verification")
def ops_approve_company_verification(
    company_key: str,
    body: CompanyVerificationApproveBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    brn = normalize_brn(company_key)
    if not brn:
        raise HTTPException(status_code=400, detail="사업자등록번호를 확인해 주세요.")

    company = db.query(Company).filter(Company.company_key == brn).first()
    member = _corporate_member_for_brn(db, brn)
    if company is None and member is None:
        raise HTTPException(status_code=404, detail="등록된 기업 회원을 찾을 수 없습니다.")

    if company is None:
        company = get_or_create_company(db, brn, member.company_name, "corporation")
        company.requires_admin_review = True
        company.verification_status = "pending"

    company.admin_review_approved = True
    company.verification_status = "verified"
    company.admin_review_reason = body.reason or "관리자 승인 완료"
    db.commit()
    db.refresh(company)
    return {
        "company_key": brn,
        "company_name": company.company_name,
        "verification_status": company.verification_status,
        "admin_review_approved": company.admin_review_approved,
    }


@router.get("/sanction/policy")
def ops_sanction_policy(_: str = Depends(require_admin_api_key)):
    return policy_catalog()


@router.get("/members/{email}/sanction")
def ops_member_sanction_status(
    email: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    status = sanction_status(db, email)
    history = list_sanction_history(db, email=email, limit=20)
    if status is None:
        return {
            "status": {
                "email": email.strip().lower(),
                "sanction_tier": "",
                "warning_count": 0,
                "restrictions": {},
            },
            "history": history,
        }
    return {"status": status, "history": history}


@router.post("/sanction/apply")
def ops_apply_policy_sanction(
    body: PolicySanctionBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return apply_policy_sanction(
            db,
            email=body.email,
            member_kind=body.member_kind,
            violation_code=body.violation_code,
            reason=body.reason,
            days=body.days,
            permanent=body.permanent,
            company_key=body.company_key,
            source="admin",
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/sanction/lift")
def ops_lift_sanction(
    body: MemberSanctionBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return lift_sanction(db, email=body.email, reason=body.reason)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


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
        digits = "".join(ch for ch in q if ch.isdigit())
        from sqlalchemy import or_

        filters = [
            QcMemberRow.email.like(like),
            QcMemberRow.display_name.like(like),
            QcMemberRow.company_name.like(like),
            QcMemberRow.phone.like(like),
            QcMemberRow.branch_name.like(like),
        ]
        if digits:
            filters.append(QcMemberRow.company_key.like(f"%{digits}%"))
        query = query.filter(or_(*filters))
    rows = query.order_by(QcMemberRow.email).limit(limit).all()
    return {
        "members": [
            {
                "email": r.email,
                "display_name": r.display_name,
                "member_type": r.member_type,
                "company_key": r.company_key,
                "company_name": r.company_name,
                "phone": r.phone,
                "org_role": r.org_role,
                "branch_name": r.branch_name,
                "department": r.department,
                "handler_code": r.handler_code,
                "created_at": r.created_at.isoformat() if r.created_at else None,
                "is_suspended": r.is_suspended,
                "is_permanently_banned": r.is_permanently_banned,
                "sanction_reason": r.sanction_reason,
                "has_password": bool(r.password_hash),
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


@router.post("/shuttle/routes/bulk-import")
async def ops_bulk_import_shuttle_routes(
    company_key: str = Form(...),
    file: UploadFile = File(...),
    replace_existing: bool = Form(default=True),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    filename = (file.filename or "").lower()
    if not filename.endswith((".xlsx", ".xlsm")):
        raise HTTPException(
            status_code=400,
            detail="엑셀 파일(.xlsx)만 업로드할 수 있습니다.",
        )
    payload = await file.read()
    if not payload:
        raise HTTPException(status_code=400, detail="파일이 비어 있습니다.")
    try:
        return bulk_import_shuttle_routes_from_excel(
            db,
            company_key=company_key,
            file_bytes=payload,
            replace_existing=replace_existing,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/jobs/preview-import-urls")
async def ops_preview_import_urls(
    body: BulkImportUrlsBody,
    _: str = Depends(require_admin_api_key),
):
    """검색/상세 URL → 공고 목록 미리보기 (DB 등록 없음)."""
    urls = body.urls or extract_urls(body.url_text)
    if not urls:
        raise HTTPException(status_code=400, detail="url 또는 url_text가 필요합니다.")
    try:
        return await preview_job_urls(urls=urls)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/jobs/bulk-import-urls")
async def ops_bulk_import_urls(
    body: BulkImportUrlsBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    urls = body.urls or extract_urls(body.url_text)
    if not urls:
        raise HTTPException(status_code=400, detail="url 또는 url_text가 필요합니다.")
    try:
        return await bulk_import_job_urls(
            db,
            urls=urls,
            company_key=body.company_key,
            company_name=body.company_name,
            posted_by_email=body.posted_by_email,
            posted_by_name=body.posted_by_name,
            activate_job_pin=body.activate_job_pin,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


class RemirrorImagesBody(BaseModel):
    post_id: str | None = None
    limit: int = Field(default=50, ge=1, le=200)


@router.post("/jobs/remirror-description-images")
async def ops_remirror_description_images(
    body: RemirrorImagesBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    """이미 등록된 공고의 알바몬 등 외부 본문 이미지를 /media/job-posts 로 복사."""
    return await remirror_job_post_images(
        db,
        post_id=(body.post_id or "").strip() or None,
        limit=body.limit,
    )


@router.get("/pilot/bus-location-tower")
def ops_get_bus_location_tower_pilot(
    company_key: str = Query(...),
    route_id: str = Query(...),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return bus_location_tower_admin_view(db, company_key=company_key, route_id=route_id)


@router.get("/pilot/bus-location-tower/candidates")
def ops_search_bus_location_tower_candidates(
    phone: str = Query(..., min_length=4),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return search_bus_location_tower_candidates(db, phone=phone)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.put("/pilot/bus-location-tower")
def ops_set_bus_location_tower_pilot(
    body: BusLocationTowerPilotBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    if body.enabled and not body.seeker_email.strip():
        raise HTTPException(status_code=400, detail="지정할 개인회원 이메일이 필요합니다.")
    try:
        return upsert_bus_location_tower(
            db,
            seeker_email=body.seeker_email,
            enabled=body.enabled,
            company_key=body.company_key,
            route_id=body.route_id,
            company_name=body.company_name,
            route_name=body.route_name,
            note=body.note,
            work_start_time=body.work_start_time,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/pilot/bus-location-tower/stop-today")
def ops_stop_bus_location_tower_today(
    company_key: str = Query(...),
    route_id: str = Query(...),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return stop_bus_location_tower_today(db, company_key=company_key, route_id=route_id)


@router.get("/pilot/officer-requests")
def ops_list_pending_officer_requests(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    items = list_pending_officer_requests(db)
    return {"items": items, "count": len(items)}


@router.post("/pilot/officer-requests/{request_id}/approve")
def ops_approve_officer_request(
    request_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return approve_officer_request(db, request_id=request_id, reviewed_by="admin")
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/pilot/officer-requests/{request_id}/reject")
def ops_reject_officer_request(
    request_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return reject_officer_request(db, request_id=request_id, reviewed_by="admin")
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.get("/shuttle/participants")
def ops_shuttle_participants(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return admin_participants_view(db)


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


@router.get("/stats")
def ops_stats(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    from app.job_sync_models import JobApplicationRow, JobPostRow

    seekers = (
        db.query(QcMemberRow).filter(QcMemberRow.member_type == "seeker").count()
    )
    corporates = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.member_type.in_(["employer", "corporate"]))
        .count()
    )
    suspended = (
        db.query(QcMemberRow)
        .filter(
            (QcMemberRow.is_suspended.is_(True))
            | (QcMemberRow.is_permanently_banned.is_(True))
        )
        .count()
    )
    jobs = db.query(JobPostRow).count()
    applications = db.query(JobApplicationRow).count()
    return {
        "seekers": seekers,
        "corporates": corporates,
        "suspended_members": suspended,
        "job_posts": jobs,
        "applications": applications,
    }


@router.get("/jobs/map")
def ops_jobs_map(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    jobs = list_jobs_for_map(db)
    return {"jobs": jobs, "count": len(jobs)}


@router.get("/jobs/map/{post_id}")
def ops_job_map_detail(
    post_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return get_job_map_detail(db, post_id=post_id)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.delete("/jobs/{post_id}")
def ops_delete_job(
    post_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    deleted = delete_job_post_admin(db, post_id=post_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="job post not found")
    return {"deleted": True, "id": post_id}


@router.get("/applications")
def ops_list_applications(
    seeker_email: str | None = Query(default=None),
    company_key: str | None = Query(default=None),
    q: str | None = Query(default=None),
    limit: int = Query(default=100, ge=1, le=500),
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    apps = list_applications_for_admin(
        db,
        seeker_email=seeker_email,
        company_key=company_key,
        q=q,
        limit=limit,
    )
    return {"applications": apps, "count": len(apps)}


@router.get("/applications/{application_id}/chat")
def ops_application_chat(
    application_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        return list_chat_for_application(db, application_id=application_id)
    except ValueError as error:
        raise HTTPException(status_code=404, detail=str(error)) from error


@router.get("/ghost-pins")
def ops_list_ghost_pins(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    pins = list_ghost_pins(db)
    return {"ghost_pins": pins, "count": len(pins)}


@router.post("/ghost-pins")
def ops_create_ghost_pin(
    body: GhostPinCreateBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    pin = create_ghost_pin(
        db,
        latitude=body.latitude,
        longitude=body.longitude,
        label=body.label,
        source_post_id=body.source_post_id,
    )
    return {"ghost_pin": pin}


@router.delete("/ghost-pins/{pin_id}")
def ops_delete_ghost_pin(
    pin_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    deleted = delete_ghost_pin(db, pin_id=pin_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="ghost pin not found")
    return {"deleted": True, "id": pin_id}


@router.get("/event-pins")
def ops_list_event_pins(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    pins = list_event_pins(db)
    return {"event_pins": pins, "count": len(pins)}


@router.post("/event-pins")
def ops_create_event_pin(
    body: EventPinCreateBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    try:
        pin = create_event_pin(
            db,
            latitude=body.latitude,
            longitude=body.longitude,
            title=body.title,
            body=body.body,
            kind=body.kind,
            color_hex=body.color_hex,
            payload=body.payload,
            active=body.active,
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    return {"event_pin": pin}


@router.delete("/event-pins/{pin_id}")
def ops_delete_event_pin(
    pin_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    deleted = delete_event_pin(db, pin_id=pin_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="event pin not found")
    return {"deleted": True, "id": pin_id}


@router.get("/ghost-routes")
def ops_list_ghost_routes(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    routes = list_ghost_routes(db)
    return {"ghost_routes": routes, "count": len(routes)}


@router.post("/ghost-routes")
def ops_create_ghost_route(
    body: GhostRouteCreateBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    route = create_ghost_route(
        db,
        workplace_latitude=body.workplace_latitude,
        workplace_longitude=body.workplace_longitude,
        stops=[s.model_dump() for s in body.stops],
        label=body.label,
    )
    return {"ghost_route": route}


@router.delete("/ghost-routes/{route_id}")
def ops_delete_ghost_route(
    route_id: str,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    deleted = delete_ghost_route(db, route_id=route_id)
    if not deleted:
        raise HTTPException(status_code=404, detail="ghost route not found")
    return {"deleted": True, "id": route_id}


@router.get("/announcements")
def ops_list_announcements(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    items = list_announcements(db)
    return {"announcements": items, "count": len(items)}


@router.post("/announcements")
def ops_create_announcement(
    body: AdminAnnouncementCreateBody,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    item = create_announcement(
        db,
        title=body.title,
        body=body.body,
        audience=body.audience,
        push_requested=body.push_requested,
    )
    return {"announcement": item}


@router.get("/compliance/workplace-mismatch/pending")
def ops_list_workplace_mismatch_pending(
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    flags = list_pending_workplace_mismatch_flags(db)
    return {"flags": flags, "count": len(flags)}


@router.post("/compliance/workplace-mismatch/{flag_id}/approve-stated-workplace")
def ops_approve_stated_workplace_post(
    flag_id: int,
    db: Session = Depends(get_db),
    _: str = Depends(require_admin_api_key),
):
    return approve_stated_workplace_post(db, flag_id=flag_id)
