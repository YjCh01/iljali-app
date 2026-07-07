"""회원 로그인·가입·계정찾기·비밀번호 재설정·휴대폰 인증."""

from __future__ import annotations

import json
from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, Header, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from app.database import get_db
from app.qc_models import QcMemberRow
from app.services.auth_token_service import (
    issue_email_verified_token,
    issue_phone_verified_token,
    issue_token,
    verify_email_verified_token,
    verify_phone_verified_token,
    verify_token,
)
from app.services.account_recovery_service import (
    find_corporate_emails,
    find_corporate_emails_by_email,
    find_seeker_emails,
    find_seeker_emails_by_email,
    reset_corporate_password,
    reset_corporate_password_by_email,
    reset_seeker_password,
    reset_seeker_password_by_email,
)
from app.services.email_verify_service import (
    normalize_email as normalize_email_address,
    send_code as send_email_code,
    verify_code as verify_email_code,
)
from app.services.password_service import (
    hash_password,
    mask_email,
    validate_password_strength,
    verify_password,
)
from app.services.entitlement_service import normalize_brn
from app.services.phone_verify_service import normalize_phone, send_code, verify_code

router = APIRouter(prefix="/v1/auth", tags=["auth"])

_ALLOWED_PHONE_PURPOSES = frozenset({"signup", "find_email", "reset_password"})
_ALLOWED_EMAIL_PURPOSES = frozenset({"find_email", "reset_password"})


def _phone_send_error_detail(exc: ValueError) -> str:
    code = str(exc)
    if code == "rate_limited":
        return "잠시 후 다시 시도해 주세요."
    if code == "invalid_phone":
        return "휴대폰 번호를 확인해 주세요."
    if code.startswith("sms_failed:"):
        return "문자 발송에 실패했습니다. 잠시 후 다시 시도해 주세요."
    return code


class LoginBody(BaseModel):
    email: str
    password: str = Field(min_length=4)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    email: str
    display_name: str
    member_type: str
    company_key: str = ""
    company_name: str = ""
    phone: str = ""
    department: str = ""
    contact_person_name: str = ""
    handler_code: str = ""
    org_role: str = ""
    seeker_profile: dict | None = None


class MeResponse(BaseModel):
    email: str
    display_name: str
    member_type: str
    company_key: str = ""
    company_name: str = ""
    phone: str = ""
    department: str = ""
    contact_person_name: str = ""
    handler_code: str = ""
    org_role: str = ""
    seeker_profile: dict | None = None


class PhoneSendBody(BaseModel):
    phone: str


class PhoneSendResponse(BaseModel):
    sent: bool
    hint: str
    mock: bool
    dev_code: str | None = None
    sms_sent: bool = True


class PhoneVerifyBody(BaseModel):
    phone: str
    code: str
    purpose: str = "signup"


class PhoneVerifyResponse(BaseModel):
    verified: bool
    phone_verified_token: str | None = None


class SignUpBody(BaseModel):
    email: str
    password: str
    phone: str
    phone_verified_token: str
    display_name: str = Field(min_length=1, max_length=100)
    seeker_profile: dict | None = None


class CorporateSignUpBody(BaseModel):
    email: str
    password: str
    display_name: str = Field(min_length=1, max_length=100)
    phone: str = ""
    phone_verified_token: str = ""
    company_name: str = Field(min_length=1, max_length=200)
    company_key: str = Field(min_length=1, max_length=20)
    department: str = ""
    contact_person_name: str = ""
    handler_code: str = ""
    org_role: str = "recruiter"


class FindEmailBody(BaseModel):
    method: str = "phone"
    display_name: str = ""
    phone: str = ""
    phone_verified_token: str = ""
    email: str = ""
    email_verified_token: str = ""


class FindEmailCorporateBody(BaseModel):
    method: str = "brn"
    contact_person_name: str = Field(min_length=1, max_length=100)
    company_key: str = ""
    email: str = ""
    email_verified_token: str = ""


class EmailSendBody(BaseModel):
    email: str


class EmailSendResponse(BaseModel):
    sent: bool
    hint: str
    mock: bool
    dev_code: str | None = None


class EmailVerifyBody(BaseModel):
    email: str
    code: str
    purpose: str = "find_email"


class EmailVerifyResponse(BaseModel):
    verified: bool
    email_verified_token: str | None = None


class PasswordResetBody(BaseModel):
    member_type: str = "seeker"
    method: str = "phone"
    email: str
    display_name: str = ""
    contact_person_name: str = ""
    company_key: str = ""
    phone: str = ""
    phone_verified_token: str = ""
    email_verified_token: str = ""
    new_password: str


class FindEmailResponse(BaseModel):
    found: bool
    masked_emails: list[str] = Field(default_factory=list)


class PasswordResetResponse(BaseModel):
    ok: bool


class SeekerProfilePatchBody(BaseModel):
    seeker_profile: dict = Field(default_factory=dict)
    display_name: str | None = None


def _parse_seeker_profile(row: QcMemberRow) -> dict | None:
    if row.member_type != "seeker":
        return None
    raw = (row.seeker_profile_json or "").strip()
    if not raw or raw == "{}":
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    return data if isinstance(data, dict) else None


def _member_to_login(row: QcMemberRow) -> LoginResponse:
    token = issue_token(
        {
            "sub": row.email,
            "member_type": row.member_type,
            "company_key": row.company_key,
        }
    )
    return LoginResponse(
        access_token=token,
        email=row.email,
        display_name=row.display_name or row.email.split("@")[0],
        member_type=row.member_type,
        company_key=row.company_key or "",
        company_name=row.company_name or "",
        phone=row.phone or "",
        department=row.department or "",
        contact_person_name=row.contact_person_name or row.display_name or "",
        handler_code=row.handler_code or "",
        org_role=row.org_role or "",
        seeker_profile=_parse_seeker_profile(row),
    )


def _member_to_me(row: QcMemberRow) -> MeResponse:
    return MeResponse(
        email=row.email,
        display_name=row.display_name,
        member_type=row.member_type,
        company_key=row.company_key,
        company_name=row.company_name,
        phone=row.phone,
        department=row.department or "",
        contact_person_name=row.contact_person_name or row.display_name or "",
        handler_code=row.handler_code or "",
        org_role=row.org_role or "",
        seeker_profile=_parse_seeker_profile(row),
    )


def _ensure_active_member(row: QcMemberRow) -> None:
    if row.is_suspended or row.is_permanently_banned:
        raise HTTPException(status_code=403, detail="이용 제한된 계정입니다.")


@router.post("/login", response_model=LoginResponse)
def login(body: LoginBody, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
    if row is None:
        raise HTTPException(
            status_code=401,
            detail="이메일 또는 비밀번호가 올바르지 않습니다.",
        )
    _ensure_active_member(row)

    if not verify_password(body.password, row.password_hash or None, email=email):
        raise HTTPException(
            status_code=401,
            detail="이메일 또는 비밀번호가 올바르지 않습니다.",
        )

    return _member_to_login(row)


@router.post("/signup", response_model=LoginResponse)
def signup(body: SignUpBody, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    phone = normalize_phone(body.phone)
    purpose = "signup"

    if not verify_phone_verified_token(
        body.phone_verified_token,
        phone=phone,
        purpose=purpose,
    ):
        raise HTTPException(
            status_code=400,
            detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
        )

    password_error = validate_password_strength(body.password)
    if password_error:
        raise HTTPException(status_code=400, detail=password_error)

    if db.query(QcMemberRow).filter(QcMemberRow.email == email).first():
        raise HTTPException(status_code=409, detail="이미 사용 중인 이메일입니다.")

    phone_taken = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.phone == phone)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    if phone_taken:
        raise HTTPException(
            status_code=409,
            detail="이미 가입된 휴대폰 번호입니다.",
        )

    profile_json = json.dumps(body.seeker_profile or {}, ensure_ascii=False)
    row = QcMemberRow(
        id=f"qc_{uuid4().hex[:12]}",
        email=email,
        display_name=body.display_name.strip(),
        member_type="seeker",
        phone=phone,
        password_hash=hash_password(body.password),
        phone_verified_at=datetime.utcnow(),
        seeker_profile_json=profile_json,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _member_to_login(row)


@router.post("/signup/corporate", response_model=LoginResponse)
def signup_corporate(body: CorporateSignUpBody, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    company_key = normalize_brn(body.company_key)
    if not company_key:
        raise HTTPException(status_code=400, detail="사업자등록번호를 확인해 주세요.")

    password_error = validate_password_strength(body.password)
    if password_error:
        raise HTTPException(status_code=400, detail=password_error)

    if db.query(QcMemberRow).filter(QcMemberRow.email == email).first():
        raise HTTPException(status_code=409, detail="이미 사용 중인 이메일입니다.")

    phone = normalize_phone(body.phone) if body.phone.strip() else ""
    if not phone:
        raise HTTPException(status_code=400, detail="휴대폰 번호를 입력해 주세요.")
    if not verify_phone_verified_token(
        body.phone_verified_token,
        phone=phone,
        purpose="signup",
    ):
        raise HTTPException(
            status_code=400,
            detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
        )

    contact_name = (body.contact_person_name or body.display_name).strip()
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
        password_hash=hash_password(body.password),
        phone_verified_at=datetime.utcnow(),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return _member_to_login(row)


@router.post("/account/find-email", response_model=FindEmailResponse)
def find_email(body: FindEmailBody, db: Session = Depends(get_db)):
    method = (body.method or "phone").strip().lower()
    display_name = body.display_name.strip()

    if method == "email":
        email = normalize_email_address(body.email)
        if not display_name:
            raise HTTPException(status_code=400, detail="이름을 입력해 주세요.")
        if not verify_email_verified_token(
            body.email_verified_token,
            email=email,
            purpose="find_email",
        ):
            raise HTTPException(
                status_code=400,
                detail="이메일 인증이 만료되었습니다. 다시 인증해 주세요.",
            )
        if display_name:
            masked = find_seeker_emails_by_email(
                db, email=email, display_name=display_name
            )
        else:
            row = (
                db.query(QcMemberRow)
                .filter(QcMemberRow.email == email)
                .filter(QcMemberRow.member_type == "seeker")
                .first()
            )
            masked = [mask_email(row.email)] if row else []
        return FindEmailResponse(found=len(masked) > 0, masked_emails=masked)

    phone = normalize_phone(body.phone)
    if not verify_phone_verified_token(
        body.phone_verified_token,
        phone=phone,
        purpose="find_email",
    ):
        raise HTTPException(
            status_code=400,
            detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
        )

    if display_name:
        masked = find_seeker_emails(
            db, phone=phone, display_name=display_name
        )
    else:
        rows = (
            db.query(QcMemberRow)
            .filter(QcMemberRow.phone == phone)
            .filter(QcMemberRow.member_type == "seeker")
            .order_by(QcMemberRow.created_at.desc())
            .all()
        )
        masked = [mask_email(row.email) for row in rows]
    return FindEmailResponse(found=len(masked) > 0, masked_emails=masked)


@router.post("/account/find-email/corporate", response_model=FindEmailResponse)
def find_email_corporate(
    body: FindEmailCorporateBody, db: Session = Depends(get_db)
):
    method = (body.method or "brn").strip().lower()
    contact_name = body.contact_person_name.strip()
    if not contact_name:
        raise HTTPException(status_code=400, detail="담당자명을 입력해 주세요.")

    if method == "email":
        email = normalize_email_address(body.email)
        if not verify_email_verified_token(
            body.email_verified_token,
            email=email,
            purpose="find_email",
        ):
            raise HTTPException(
                status_code=400,
                detail="이메일 인증이 만료되었습니다. 다시 인증해 주세요.",
            )
        masked = find_corporate_emails_by_email(
            db, email=email, contact_person_name=contact_name
        )
        return FindEmailResponse(found=len(masked) > 0, masked_emails=masked)

    company_key = normalize_brn(body.company_key)
    if not company_key:
        raise HTTPException(
            status_code=400, detail="사업자등록번호를 확인해 주세요."
        )
    masked = find_corporate_emails(
        db, company_key=company_key, contact_person_name=contact_name
    )
    return FindEmailResponse(found=len(masked) > 0, masked_emails=masked)


@router.post("/password/reset", response_model=PasswordResetResponse)
def reset_password(body: PasswordResetBody, db: Session = Depends(get_db)):
    email = body.email.strip().lower()
    member_type = (body.member_type or "seeker").strip().lower()
    method = (body.method or "phone").strip().lower()

    password_error = validate_password_strength(body.new_password)
    if password_error:
        raise HTTPException(status_code=400, detail=password_error)

    password_hash = hash_password(body.new_password)
    row: QcMemberRow | None = None

    if member_type in {"corporate", "employer"}:
        contact_name = (body.contact_person_name or body.display_name).strip()
        if not contact_name:
            raise HTTPException(status_code=400, detail="담당자명을 입력해 주세요.")
        if method == "email":
            if not verify_email_verified_token(
                body.email_verified_token,
                email=email,
                purpose="reset_password",
            ):
                raise HTTPException(
                    status_code=400,
                    detail="이메일 인증이 만료되었습니다. 다시 인증해 주세요.",
                )
            row = reset_corporate_password_by_email(
                db,
                email=email,
                contact_person_name=contact_name,
                password_hash=password_hash,
            )
        else:
            phone = normalize_phone(body.phone)
            if not verify_phone_verified_token(
                body.phone_verified_token,
                phone=phone,
                purpose="reset_password",
            ):
                raise HTTPException(
                    status_code=400,
                    detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
                )
            row = reset_corporate_password(
                db,
                email=email,
                phone=phone,
                contact_person_name=contact_name,
                password_hash=password_hash,
            )
    else:
        display_name = body.display_name.strip()
        if method == "email":
            if not display_name:
                raise HTTPException(status_code=400, detail="이름을 입력해 주세요.")
            if not verify_email_verified_token(
                body.email_verified_token,
                email=email,
                purpose="reset_password",
            ):
                raise HTTPException(
                    status_code=400,
                    detail="이메일 인증이 만료되었습니다. 다시 인증해 주세요.",
                )
            row = reset_seeker_password_by_email(
                db,
                email=email,
                display_name=display_name,
                password_hash=password_hash,
            )
        else:
            phone = normalize_phone(body.phone)
            if not verify_phone_verified_token(
                body.phone_verified_token,
                phone=phone,
                purpose="reset_password",
            ):
                raise HTTPException(
                    status_code=400,
                    detail="휴대폰 인증이 만료되었습니다. 다시 인증해 주세요.",
                )
            if display_name:
                row = reset_seeker_password(
                    db,
                    email=email,
                    phone=phone,
                    display_name=display_name,
                    password_hash=password_hash,
                )
            else:
                legacy = (
                    db.query(QcMemberRow)
                    .filter(QcMemberRow.email == email)
                    .filter(QcMemberRow.phone == phone)
                    .filter(QcMemberRow.member_type == "seeker")
                    .first()
                )
                if legacy is not None:
                    legacy.password_hash = password_hash
                    row = legacy

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="입력하신 정보와 일치하는 계정을 찾을 수 없습니다.",
        )
    _ensure_active_member(row)
    db.commit()
    return PasswordResetResponse(ok=True)


@router.post("/email/send", response_model=EmailSendResponse)
def email_send(body: EmailSendBody):
    try:
        hint, mock = send_email_code(body.email)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    return EmailSendResponse(
        sent=True,
        hint=hint,
        mock=mock,
        dev_code="123456" if mock else None,
    )


@router.post("/email/verify", response_model=EmailVerifyResponse)
def email_verify(body: EmailVerifyBody):
    ok = verify_email_code(body.email, body.code)
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="인증번호가 올바르지 않거나 만료되었습니다.",
        )
    email = normalize_email_address(body.email)
    purpose = (
        body.purpose if body.purpose in _ALLOWED_EMAIL_PURPOSES else "find_email"
    )
    token = issue_email_verified_token(email, purpose=purpose)
    return EmailVerifyResponse(verified=True, email_verified_token=token)


def _resolve_bearer(authorization: str | None) -> dict:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(status_code=401, detail="인증이 필요합니다.")
    token = authorization.split(" ", 1)[1].strip()
    payload = verify_token(token)
    if payload is None:
        raise HTTPException(status_code=401, detail="세션이 만료되었습니다.")
    return payload


@router.get("/me", response_model=MeResponse)
def me(
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    email = str(payload.get("sub", "")).lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
    if row is None:
        return MeResponse(
            email=email,
            display_name=email.split("@")[0],
            member_type=str(payload.get("member_type", "seeker")),
            company_key=str(payload.get("company_key", "")),
        )
    return _member_to_me(row)


@router.patch("/me/seeker-profile", response_model=MeResponse)
def patch_seeker_profile(
    body: SeekerProfilePatchBody,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    payload = _resolve_bearer(authorization)
    email = str(payload.get("sub", "")).lower()
    row = db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
    if row is None:
        raise HTTPException(status_code=404, detail="회원 정보를 찾을 수 없습니다.")
    if row.member_type != "seeker":
        raise HTTPException(status_code=400, detail="개인회원만 프로필을 저장할 수 있습니다.")
    _ensure_active_member(row)

    row.seeker_profile_json = json.dumps(
        body.seeker_profile or {},
        ensure_ascii=False,
    )
    if body.display_name and body.display_name.strip():
        row.display_name = body.display_name.strip()
    db.commit()
    db.refresh(row)
    return _member_to_me(row)


@router.post("/phone/send", response_model=PhoneSendResponse)
def phone_send(body: PhoneSendBody):
    try:
        result = send_code(body.phone)
    except ValueError as exc:
        detail = _phone_send_error_detail(exc)
        raise HTTPException(status_code=400, detail=detail) from exc
    return PhoneSendResponse(
        sent=True,
        hint=result.hint,
        mock=result.mock,
        dev_code="123456" if result.mock else None,
        sms_sent=result.sms_sent,
    )


@router.post("/phone/verify", response_model=PhoneVerifyResponse)
def phone_verify(body: PhoneVerifyBody):
    ok = verify_code(body.phone, body.code)
    if not ok:
        raise HTTPException(
            status_code=400,
            detail="인증번호가 올바르지 않거나 만료되었습니다.",
        )
    phone = normalize_phone(body.phone)
    purpose = body.purpose if body.purpose in _ALLOWED_PHONE_PURPOSES else "signup"
    token = issue_phone_verified_token(phone, purpose=purpose)
    return PhoneVerifyResponse(verified=True, phone_verified_token=token)
