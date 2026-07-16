"""소셜 로그인 OAuth — start/callback/signup."""

from __future__ import annotations

import json
import logging
import secrets
from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.qc_models import MemberSocialLinkRow, QcMemberRow
from app.services.auth_token_service import (
    issue_oauth_state_token,
    issue_social_signup_token,
    issue_token,
    verify_oauth_state_token,
    verify_phone_verified_token,
    verify_social_signup_token,
)
from app.services.entitlement_service import normalize_brn
from app.services.password_service import hash_password, validate_password_strength
from app.services.phone_verify_service import normalize_phone
from app.services.social_auth_service import (
    SOCIAL_PROVIDERS,
    SocialProfile,
    build_app_redirect_url,
    build_authorize_url,
    exchange_code_for_profile,
    provider_configured,
    social_mock_enabled,
)
from app.routers.auth import LoginResponse, _ensure_active_member, _member_to_login

router = APIRouter(prefix="/v1/auth/social", tags=["auth-social"])
logger = logging.getLogger(__name__)


class SocialSignupBody(BaseModel):
    social_token: str
    phone: str
    phone_verified_token: str
    password: str = Field(default="", min_length=0)
    display_name: str = ""


class CorporateSocialSignupBody(BaseModel):
    social_token: str
    phone: str
    phone_verified_token: str
    display_name: str = Field(min_length=1, max_length=100)
    company_name: str = Field(min_length=1, max_length=200)
    company_key: str = Field(min_length=1, max_length=20)
    department: str = ""
    contact_person_name: str = ""
    handler_code: str = ""
    org_role: str = "recruiter"


class SocialStatusResponse(BaseModel):
    mock: bool
    providers: dict[str, bool]
    kakao_secret_configured: bool = False


@router.get("/status", response_model=SocialStatusResponse)
def social_status():
    from app.services.social_auth_service import kakao_oauth_secret_configured

    return SocialStatusResponse(
        mock=social_mock_enabled(),
        providers={name: provider_configured(name) for name in sorted(SOCIAL_PROVIDERS)},
        kakao_secret_configured=kakao_oauth_secret_configured(),
    )


@router.get("/{provider}/start")
def social_start(
    provider: str,
    member_type: str = "seeker",
    action: str = "login",
    app_redirect: str = "",
):
    normalized = provider.strip().lower()
    if normalized not in SOCIAL_PROVIDERS:
        raise HTTPException(status_code=400, detail="지원하지 않는 소셜 로그인입니다.")
    if not provider_configured(normalized):
        raise HTTPException(
            status_code=503,
            detail=f"{normalized} 로그인 설정이 아직 완료되지 않았습니다.",
        )

    member = member_type.strip().lower()
    if member not in {"seeker", "corporate", "employer"}:
        member = "seeker"

    redirect_target = app_redirect.strip() or ""
    state = issue_oauth_state_token(
        provider=normalized,
        member_type=member,
        action=action.strip().lower() or "login",
        app_redirect=redirect_target,
    )
    try:
        url = build_authorize_url(provider=normalized, state=state)
    except ValueError as exc:
        code = str(exc)
        if code == "kakao_client_id_invalid_length":
            raise HTTPException(
                status_code=503,
                detail=(
                    "카카오 REST API 키가 잘렸거나 잘못되었습니다. "
                    "서버 .env의 KAKAO_OAUTH_CLIENT_ID를 콘솔에서 32자 전체 복사해 넣으세요 (KOE101)."
                ),
            ) from exc
        raise HTTPException(status_code=503, detail=code) from exc
    return RedirectResponse(url=url, status_code=302)


@router.get("/{provider}/callback")
def social_callback(
    provider: str,
    code: str = "",
    state: str = "",
    error: str = "",
    db: Session = Depends(get_db),
):
    normalized = provider.strip().lower()
    state_payload = verify_oauth_state_token(state) if state else None
    app_redirect = (
        str(state_payload.get("app_redirect") or "")
        if state_payload
        else ""
    )

    if error:
        url = build_app_redirect_url(
            app_redirect=app_redirect,
            status="error",
            provider=normalized,
            error=error,
        )
        return RedirectResponse(url=url, status_code=302)

    if state_payload is None:
        url = build_app_redirect_url(
            app_redirect=app_redirect,
            status="error",
            provider=normalized,
            error="invalid_state",
        )
        return RedirectResponse(url=url, status_code=302)

    if state_payload.get("provider") != normalized:
        url = build_app_redirect_url(
            app_redirect=app_redirect,
            status="error",
            provider=normalized,
            error="provider_mismatch",
        )
        return RedirectResponse(url=url, status_code=302)

    if not code:
        url = build_app_redirect_url(
            app_redirect=app_redirect,
            status="error",
            provider=normalized,
            error="missing_code",
        )
        return RedirectResponse(url=url, status_code=302)

    try:
        profile = exchange_code_for_profile(
            provider=normalized, code=code, state=state
        )
    except ValueError as exc:
        error_code = str(exc) or "oauth_failed"
        url = build_app_redirect_url(
            app_redirect=app_redirect,
            status="error",
            provider=normalized,
            error=error_code,
        )
        return RedirectResponse(url=url, status_code=302)
    except Exception:
        logger.exception("social oauth callback failed provider=%s", normalized)
        url = build_app_redirect_url(
            app_redirect=app_redirect,
            status="error",
            provider=normalized,
            error="oauth_failed",
        )
        return RedirectResponse(url=url, status_code=302)

    member_type = str(state_payload.get("member_type") or "seeker")
    link = (
        db.query(MemberSocialLinkRow)
        .filter(MemberSocialLinkRow.provider == profile.provider)
        .filter(MemberSocialLinkRow.provider_user_id == profile.provider_user_id)
        .first()
    )
    if link is not None:
        row = db.query(QcMemberRow).filter(QcMemberRow.id == link.member_id).first()
        if row is not None:
            try:
                _ensure_active_member(row)
            except HTTPException:
                url = build_app_redirect_url(
                    app_redirect=app_redirect,
                    status="error",
                    provider=normalized,
                    error="account_restricted",
                )
                return RedirectResponse(url=url, status_code=302)
            login = _member_to_login(row)
            url = build_app_redirect_url(
                app_redirect=app_redirect,
                status="login",
                access_token=login.access_token,
                email=login.email,
                display_name=login.display_name,
                provider=normalized,
                member_type=login.member_type,
            )
            return RedirectResponse(url=url, status_code=302)

    social_token = issue_social_signup_token(
        provider=profile.provider,
        provider_user_id=profile.provider_user_id,
        email=profile.email,
        display_name=profile.display_name,
        member_type=member_type,
    )
    url = build_app_redirect_url(
        app_redirect=app_redirect,
        status="signup_needed",
        social_token=social_token,
        email=profile.email,
        display_name=profile.display_name,
        provider=normalized,
        member_type=member_type,
    )
    return RedirectResponse(url=url, status_code=302)


@router.post("/signup", response_model=LoginResponse)
def social_signup(body: SocialSignupBody, db: Session = Depends(get_db)):
    payload = verify_social_signup_token(body.social_token)
    if payload is None:
        raise HTTPException(
            status_code=400,
            detail="소셜 가입 정보가 만료되었습니다. 다시 시도해 주세요.",
        )

    phone = normalize_phone(body.phone)
    if not verify_phone_verified_token(
        body.phone_verified_token,
        phone=phone,
        purpose="signup",
    ):
        raise HTTPException(
            status_code=400,
            detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
        )

    provider = str(payload.get("provider") or "")
    provider_user_id = str(payload.get("provider_user_id") or "")
    email = str(payload.get("email") or "").strip().lower()
    display_name = (body.display_name or str(payload.get("display_name") or "")).strip()
    member_type = str(payload.get("member_type") or "seeker")
    if member_type in {"employer"}:
        member_type = "corporate"
    if member_type != "seeker":
        raise HTTPException(
            status_code=400,
            detail="기업 소셜 가입은 기업 가입 화면에서 진행해 주세요.",
        )

    if not display_name:
        raise HTTPException(status_code=400, detail="이름을 입력해 주세요.")

    existing_link = (
        db.query(MemberSocialLinkRow)
        .filter(MemberSocialLinkRow.provider == provider)
        .filter(MemberSocialLinkRow.provider_user_id == provider_user_id)
        .first()
    )
    if existing_link is not None:
        row = db.query(QcMemberRow).filter(QcMemberRow.id == existing_link.member_id).first()
        if row is not None:
            return _member_to_login(row)

    if db.query(QcMemberRow).filter(QcMemberRow.email == email).first():
        raise HTTPException(status_code=409, detail="이미 사용 중인 이메일입니다.")

    existing_by_phone = (
        db.query(QcMemberRow).filter(QcMemberRow.phone == phone).first()
    )
    if existing_by_phone is not None:
        if existing_by_phone.member_type in {"corporate", "employer"}:
            raise HTTPException(
                status_code=409,
                detail=(
                    "이 휴대폰 번호는 기업회원으로 가입되어 있습니다. "
                    "기업회원 로그인을 이용해 주세요."
                ),
            )
        if existing_by_phone.member_type == "seeker":
            try:
                _ensure_active_member(existing_by_phone)
            except HTTPException as exc:
                raise HTTPException(
                    status_code=exc.status_code,
                    detail=str(exc.detail),
                ) from exc
            db.add(
                MemberSocialLinkRow(
                    id=f"soc_{uuid4().hex[:12]}",
                    provider=provider,
                    provider_user_id=provider_user_id,
                    member_id=existing_by_phone.id,
                    email=existing_by_phone.email,
                    display_name=existing_by_phone.display_name or display_name,
                )
            )
            db.commit()
            db.refresh(existing_by_phone)
            return _member_to_login(existing_by_phone)

    password = body.password.strip()
    if password:
        password_error = validate_password_strength(password)
        if password_error:
            raise HTTPException(status_code=400, detail=password_error)
        password_hash = hash_password(password)
    else:
        password_hash = hash_password(secrets.token_urlsafe(24))

    row = QcMemberRow(
        id=f"qc_{uuid4().hex[:12]}",
        email=email,
        display_name=display_name,
        member_type="seeker",
        phone=phone,
        password_hash=password_hash,
        phone_verified_at=datetime.utcnow(),
        seeker_profile_json=json.dumps({}, ensure_ascii=False),
    )
    db.add(row)
    db.flush()
    db.add(
        MemberSocialLinkRow(
            id=f"soc_{uuid4().hex[:12]}",
            provider=provider,
            provider_user_id=provider_user_id,
            member_id=row.id,
            email=email,
            display_name=display_name,
        )
    )
    db.commit()
    db.refresh(row)
    return _member_to_login(row)


@router.post("/corporate-signup", response_model=LoginResponse)
def social_corporate_signup(
    body: CorporateSocialSignupBody, db: Session = Depends(get_db)
):
    """기업회원 소셜 가입 완료 — social_token으로 본인확인, 비밀번호 없이 계정 생성."""
    payload = verify_social_signup_token(body.social_token)
    if payload is None:
        raise HTTPException(
            status_code=400,
            detail="소셜 가입 정보가 만료되었습니다. 다시 시도해 주세요.",
        )

    provider = str(payload.get("provider") or "")
    provider_user_id = str(payload.get("provider_user_id") or "")
    email = str(payload.get("email") or "").strip().lower()
    member_type = str(payload.get("member_type") or "")
    if member_type not in {"corporate", "employer"}:
        raise HTTPException(
            status_code=400,
            detail="개인회원 소셜 가입은 다른 화면에서 진행해 주세요.",
        )
    if not email:
        raise HTTPException(status_code=400, detail="소셜 계정 이메일을 확인할 수 없습니다.")

    phone = normalize_phone(body.phone)
    if not verify_phone_verified_token(
        body.phone_verified_token,
        phone=phone,
        purpose="signup",
    ):
        raise HTTPException(
            status_code=400,
            detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
        )

    company_key = normalize_brn(body.company_key)
    if not company_key:
        raise HTTPException(status_code=400, detail="사업자등록번호를 확인해 주세요.")

    existing_link = (
        db.query(MemberSocialLinkRow)
        .filter(MemberSocialLinkRow.provider == provider)
        .filter(MemberSocialLinkRow.provider_user_id == provider_user_id)
        .first()
    )
    if existing_link is not None:
        row = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.id == existing_link.member_id)
            .first()
        )
        if row is not None:
            return _member_to_login(row)

    if db.query(QcMemberRow).filter(QcMemberRow.email == email).first():
        raise HTTPException(status_code=409, detail="이미 사용 중인 이메일입니다.")

    handler_code = body.handler_code.strip()
    if handler_code:
        taken = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.company_key == company_key)
            .filter(QcMemberRow.handler_code == handler_code)
            .first()
        )
        if taken:
            raise HTTPException(
                status_code=409,
                detail="이미 사용 중인 담당자 코드입니다.",
            )

    contact_name = (body.contact_person_name or body.display_name).strip()
    row = QcMemberRow(
        id=f"qc_{uuid4().hex[:12]}",
        email=email,
        display_name=body.display_name.strip(),
        member_type="corporate",
        company_key=company_key,
        company_name=body.company_name.strip(),
        phone=phone,
        department=body.department.strip(),
        contact_person_name=contact_name,
        handler_code=handler_code,
        org_role=body.org_role.strip() or "recruiter",
        # 소셜 로그인 전용 — 본인은 절대 알 수 없는 랜덤 비밀번호(로그인은 소셜 버튼으로만).
        password_hash=hash_password(secrets.token_urlsafe(24)),
        phone_verified_at=datetime.utcnow(),
    )
    db.add(row)
    db.flush()
    db.add(
        MemberSocialLinkRow(
            id=f"soc_{uuid4().hex[:12]}",
            provider=provider,
            provider_user_id=provider_user_id,
            member_id=row.id,
            email=email,
            display_name=row.display_name,
        )
    )
    db.commit()
    db.refresh(row)
    return _member_to_login(row)
