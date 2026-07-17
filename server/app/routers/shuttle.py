"""통근 셔틀 — 노선·공유·선택 API."""

from typing import Any

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobApplicationRow
from app.services.auth_token_service import verify_token
from app.services.pilot_program_service import (
    bus_location_tower_admin_view,
    create_officer_request,
    list_officer_requests_for_company,
)
from app.services.shuttle_commute_service import (
    admin_participants_view,
    deactivate_commute_route,
    delete_commute_route,
    delete_seeker_preference,
    get_route_by_id,
    list_consents_for_seeker,
    list_preferences_for_seeker,
    list_routes_for_company,
    offer_route_share,
    refresh_route_geometry,
    seeker_may_view_company_routes,
    upsert_commute_route,
    upsert_seeker_consent,
    upsert_seeker_preference,
)

router = APIRouter(prefix="/v1/shuttle", tags=["shuttle"])


def _normalize_company_key(key: str) -> str:
    return key.strip()


def _resolve_bearer(authorization: str | None) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="인증이 필요합니다.")
    token = authorization.split(" ", 1)[1].strip()
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=403, detail="세션이 만료되었습니다.")
    return payload


def _assert_corporate_company(payload: dict, company_key: str) -> None:
    if str(payload.get("member_type", "")) != "corporate":
        raise HTTPException(status_code=403, detail="기업회원만 이용할 수 있습니다.")
    token_company = _normalize_company_key(str(payload.get("company_key", "")))
    if token_company != _normalize_company_key(company_key):
        raise HTTPException(status_code=403, detail="본인 회사 노선만 처리할 수 있습니다.")


class ShuttleRouteShareOfferBody(BaseModel):
    application_id: str = Field(min_length=1, max_length=64)
    company_key: str = Field(min_length=1, max_length=10)
    company_name: str = Field(default="", max_length=200)
    route_count: int = Field(default=0, ge=0, le=100)


class ShuttleRouteShareConsentBody(BaseModel):
    company_key: str = Field(min_length=1, max_length=10)
    opted_in: bool
    tower_participation_consented: bool = False
    route_id: str = ""
    stop_id: str = ""
    pickup_time: str = ""


class ShuttleOfficerRequestBody(BaseModel):
    seeker_email: str = Field(min_length=1)
    seeker_name: str = ""
    route_id: str = Field(min_length=1, max_length=64)
    route_name: str = ""
    company_name: str = ""
    note: str = ""
    work_start_time: str = ""


class ShuttlePreferenceBody(BaseModel):
    company_key: str = Field(min_length=1, max_length=10)
    company_name: str = ""
    route_id: str = Field(min_length=1, max_length=64)
    route_name: str = ""
    stop_id: str = ""
    stop_label: str = ""
    pickup_time: str = ""


@router.get("/routes")
def shuttle_list_routes(
    company_key: str = Query(min_length=1, max_length=10),
    include_inactive: bool = Query(default=False),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    company = _normalize_company_key(company_key)
    member_type = str(payload.get("member_type", "seeker"))
    if member_type == "corporate":
        _assert_corporate_company(payload, company)
    elif member_type == "seeker":
        email = str(payload.get("sub", "")).lower()
        if not seeker_may_view_company_routes(db, seeker_email=email, company_key=company):
            raise HTTPException(status_code=403, detail="노선 조회 권한이 없습니다.")
    else:
        raise HTTPException(status_code=403, detail="권한이 없습니다.")
    items = list_routes_for_company(db, company_key=company, active_only=not include_inactive)
    return {"items": items, "count": len(items)}


@router.get("/routes/{route_id}")
def shuttle_get_route(
    route_id: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    row = get_route_by_id(db, route_id=route_id)
    if row is None:
        raise HTTPException(status_code=404, detail="노선을 찾을 수 없습니다.")
    company = _normalize_company_key(str(row.get("companyKey", "")))
    member_type = str(payload.get("member_type", "seeker"))
    if member_type == "corporate":
        _assert_corporate_company(payload, company)
    elif member_type == "seeker":
        email = str(payload.get("sub", "")).lower()
        if not seeker_may_view_company_routes(db, seeker_email=email, company_key=company):
            raise HTTPException(status_code=403, detail="노선 조회 권한이 없습니다.")
    else:
        raise HTTPException(status_code=403, detail="권한이 없습니다.")
    return row


@router.put("/routes/{route_id}")
def shuttle_upsert_route(
    route_id: str,
    body: dict[str, Any],
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    body = dict(body)
    body["id"] = route_id.strip()
    company_key = _normalize_company_key(str(body.get("companyKey", "")))
    _assert_corporate_company(payload, company_key)
    try:
        return upsert_commute_route(db, route=body)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/routes/{route_id}/refresh-geometry")
def shuttle_refresh_route_geometry(
    route_id: str,
    company_key: str = Query(min_length=1, max_length=10),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """Re-densify road-following polylinePoints from current stops."""
    payload = _resolve_bearer(authorization)
    _assert_corporate_company(payload, company_key)
    try:
        row = refresh_route_geometry(
            db, route_id=route_id, company_key=company_key
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error
    if row is None:
        raise HTTPException(status_code=404, detail="노선을 찾을 수 없습니다.")
    return row


@router.delete("/routes/{route_id}")
def shuttle_delete_route(
    route_id: str,
    company_key: str = Query(min_length=1, max_length=10),
    hard: bool = Query(default=False),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    _assert_corporate_company(payload, company_key)
    try:
        if hard:
            deleted = delete_commute_route(
                db, company_key=company_key, route_id=route_id
            )
            if not deleted:
                raise HTTPException(status_code=404, detail="노선을 찾을 수 없습니다.")
            return {"deleted": True}
        row = deactivate_commute_route(
            db, company_key=company_key, route_id=route_id
        )
        if row is None:
            raise HTTPException(status_code=404, detail="노선을 찾을 수 없습니다.")
        return row
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.post("/route-share/offer")
def shuttle_route_share_offer(
    body: ShuttleRouteShareOfferBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    app_row = db.get(JobApplicationRow, body.application_id.strip())
    if app_row is None:
        raise HTTPException(status_code=404, detail="지원 건을 찾을 수 없습니다.")
    seeker_email = str(app_row.seeker_email or "").lower()
    member_type = str(payload.get("member_type", "seeker"))
    sub = str(payload.get("sub", "")).lower()
    company_key = _normalize_company_key(body.company_key)
    if member_type == "seeker":
        if sub != seeker_email:
            raise HTTPException(status_code=403, detail="본인 지원 건만 처리할 수 있습니다.")
    elif member_type == "corporate":
        if _normalize_company_key(str(app_row.company_key or "")) != company_key:
            raise HTTPException(status_code=403, detail="해당 회사 지원 건만 처리할 수 있습니다.")
    else:
        raise HTTPException(status_code=403, detail="권한이 없습니다.")
    return offer_route_share(
        db,
        seeker_email=seeker_email,
        application_id=body.application_id,
        company_key=body.company_key,
        company_name=body.company_name or app_row.company_name,
        route_count=body.route_count,
    )


@router.get("/route-share/me")
def shuttle_route_share_me(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    if str(payload.get("member_type", "seeker")) != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    items = list_consents_for_seeker(db, email=email)
    return {"items": items}


@router.put("/route-share/consent")
def shuttle_route_share_consent(
    body: ShuttleRouteShareConsentBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    if str(payload.get("member_type", "seeker")) != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    if body.opted_in and not body.tower_participation_consented:
        raise HTTPException(
            status_code=400,
            detail="노선 공유 수신 시 관제탑 프로세스 참여 동의가 필요합니다.",
        )
    row = upsert_seeker_consent(
        db,
        seeker_email=email,
        company_key=body.company_key,
        opted_in=body.opted_in,
        tower_participation_consented=body.tower_participation_consented,
        route_id=body.route_id,
        stop_id=body.stop_id,
        pickup_time=body.pickup_time,
    )
    return row


@router.get("/preferences/me")
def shuttle_preferences_me(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    if str(payload.get("member_type", "seeker")) != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    items = list_preferences_for_seeker(db, email=email)
    return {"items": items}


@router.put("/preferences")
def shuttle_upsert_preference(
    body: ShuttlePreferenceBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    if str(payload.get("member_type", "seeker")) != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    return upsert_seeker_preference(
        db,
        seeker_email=email,
        company_key=body.company_key,
        company_name=body.company_name,
        route_id=body.route_id,
        route_name=body.route_name,
        stop_id=body.stop_id,
        stop_label=body.stop_label,
        pickup_time=body.pickup_time,
    )


@router.delete("/preferences")
def shuttle_delete_preference(
    company_key: str = Query(min_length=1, max_length=10),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    if str(payload.get("member_type", "seeker")) != "seeker":
        raise HTTPException(status_code=403, detail="개인회원만 이용할 수 있습니다.")
    email = str(payload.get("sub", "")).lower()
    delete_seeker_preference(db, seeker_email=email, company_key=company_key)
    return {"deleted": True}


@router.get("/location-officer")
def shuttle_get_location_officer(
    route_id: str = Query(min_length=1, max_length=64),
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """고용주 자기 회사의 버스위치 공유 담당 지정 현황 — 어드민 화면과 동일 데이터."""
    payload = _resolve_bearer(authorization)
    company_key = _normalize_company_key(str(payload.get("company_key", "")))
    _assert_corporate_company(payload, company_key)
    return bus_location_tower_admin_view(db, company_key=company_key, route_id=route_id)


@router.post("/location-officer/request")
def shuttle_request_location_officer(
    body: ShuttleOfficerRequestBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """고용주 — 버스위치 공유 담당 지정을 어드민에 승인요청 (즉시 반영되지 않음).

    company_key는 토큰에서만 가져온다(다른 회사 지정 원천 차단)."""
    payload = _resolve_bearer(authorization)
    company_key = _normalize_company_key(str(payload.get("company_key", "")))
    _assert_corporate_company(payload, company_key)
    try:
        return create_officer_request(
            db,
            company_key=company_key,
            company_name=body.company_name,
            route_id=body.route_id,
            route_name=body.route_name,
            seeker_email=body.seeker_email,
            seeker_name=body.seeker_name,
            work_start_time=body.work_start_time,
            note=body.note,
            requested_by=str(payload.get("sub", "")),
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error


@router.get("/location-officer/requests")
def shuttle_list_location_officer_requests(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """고용주 — 자기 회사가 보낸 버스위치 공유 담당 지정 요청 목록·처리 상태."""
    payload = _resolve_bearer(authorization)
    company_key = _normalize_company_key(str(payload.get("company_key", "")))
    _assert_corporate_company(payload, company_key)
    items = list_officer_requests_for_company(db, company_key=company_key)
    return {"items": items, "count": len(items)}
