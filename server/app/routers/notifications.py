from typing import Annotated

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.services.auth_token_service import verify_token
from app.services.push_dispatch_hooks import push_recruitment_targets
from app.services.push_notification_service import (
    fcm_service,
    register_device_token,
    unregister_device_token,
    update_preferences,
)

router = APIRouter(prefix="/v1/notifications", tags=["notifications"])


class AlimtalkRequest(BaseModel):
    template_code: str
    recipient_phone: str
    recipient_name: str = ""
    variables: dict[str, str] = Field(default_factory=dict)
    fallback_body: str = ""


class DeviceRegisterBody(BaseModel):
    fcm_token: str = Field(min_length=10)
    platform: str = "web"
    chat_enabled: bool = True
    job_alerts_enabled: bool = True
    application_updates_enabled: bool = True


class DevicePreferencesBody(BaseModel):
    fcm_token: str = Field(min_length=10)
    chat_enabled: bool | None = None
    job_alerts_enabled: bool | None = None
    application_updates_enabled: bool | None = None


class RecruitmentTargetBody(BaseModel):
    latitude: float
    longitude: float
    radius_meters: int = Field(default=1000, ge=100, le=5000)
    label: str = ""


class RecruitmentPushBody(BaseModel):
    post_id: str
    title: str = ""
    company_name: str = ""
    company_key: str = ""
    targets: list[RecruitmentTargetBody] = Field(min_length=1)


def _resolve_bearer(authorization: str | None) -> dict:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="로그인이 필요합니다.")
    token = authorization.removeprefix("Bearer ").strip()
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="세션이 만료되었습니다.")
    return payload


def _member_type(payload: dict) -> str:
    raw = str(payload.get("member_type", "seeker")).strip().lower()
    if raw in {"corporate", "employer"}:
        return "corporate"
    return "seeker"


@router.get("/status")
def notification_status():
    return {
        "fcm_enabled": fcm_service.enabled,
        "channels": ["fcm_web", "in_app"],
    }


@router.post("/devices/register")
def register_device(
    body: DeviceRegisterBody,
    db: Session = Depends(get_db),
    authorization: Annotated[str | None, Header()] = None,
):
    payload = _resolve_bearer(authorization)
    email = str(payload.get("sub", "")).strip().lower()
    if not email:
        raise HTTPException(status_code=400, detail="회원 이메일이 없습니다.")
    item = register_device_token(
        db,
        member_email=email,
        member_type=_member_type(payload),
        fcm_token=body.fcm_token,
        platform=body.platform,
        chat_enabled=body.chat_enabled,
        job_alerts_enabled=body.job_alerts_enabled,
        application_updates_enabled=body.application_updates_enabled,
    )
    return {"device": item, "fcm_enabled": fcm_service.enabled}


@router.delete("/devices/register")
def unregister_device(
    fcm_token: str,
    db: Session = Depends(get_db),
    authorization: Annotated[str | None, Header()] = None,
):
    _resolve_bearer(authorization)
    removed = unregister_device_token(db, fcm_token=fcm_token)
    return {"removed": removed}


@router.patch("/devices/preferences")
def patch_device_preferences(
    body: DevicePreferencesBody,
    db: Session = Depends(get_db),
    authorization: Annotated[str | None, Header()] = None,
):
    payload = _resolve_bearer(authorization)
    email = str(payload.get("sub", "")).strip().lower()
    item = update_preferences(
        db,
        member_email=email,
        fcm_token=body.fcm_token,
        chat_enabled=body.chat_enabled,
        job_alerts_enabled=body.job_alerts_enabled,
        application_updates_enabled=body.application_updates_enabled,
    )
    if item is None:
        raise HTTPException(status_code=404, detail="등록된 기기를 찾을 수 없습니다.")
    return {"device": item}


@router.post("/push/recruitment")
def dispatch_recruitment_push(
    body: RecruitmentPushBody,
    db: Session = Depends(get_db),
    authorization: Annotated[str | None, Header()] = None,
):
    payload = _resolve_bearer(authorization)
    if _member_type(payload) != "corporate":
        raise HTTPException(status_code=403, detail="기업회원만 PUSH 발송할 수 있습니다.")

    token_company = str(payload.get("company_key", "")).strip()
    if body.company_key and token_company:
        if body.company_key.strip() != token_company:
            raise HTTPException(status_code=403, detail="회사 정보가 일치하지 않습니다.")

    result = push_recruitment_targets(
        db,
        post_id=body.post_id,
        title=body.title,
        company_name=body.company_name,
        company_key=body.company_key or token_company,
        targets=[target.model_dump() for target in body.targets],
    )
    return {"ok": True, **result, "fcm_enabled": fcm_service.enabled}


@router.post("/alimtalk")
async def send_alimtalk(body: AlimtalkRequest):
    print(
        "[alimtalk]",
        body.template_code,
        body.recipient_phone,
        body.fallback_body,
    )
    return {
        "delivered": True,
        "channel": "kakao_alimtalk_mock",
        "message": body.fallback_body,
    }
