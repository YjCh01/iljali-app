"""Auth router tests."""

import json
from unittest.mock import patch
from uuid import uuid4

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.main import app
from app.qc_models import QcMemberRow
from app.services.entitlement_service import normalize_brn
from app.services import phone_verify_service as phone_svc

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if not db.query(QcMemberRow).filter(
            QcMemberRow.email == "seeker-0001@qc.iljari.co.kr"
        ).first():
            db.add(
                QcMemberRow(
                    id="qc_seeker_1",
                    email="seeker-0001@qc.iljari.co.kr",
                    display_name="SEEKER 0001",
                    member_type="seeker",
                )
            )
            db.commit()
    finally:
        db.close()


def _verify_phone(phone: str, *, purpose: str = "signup") -> str:
    phone_svc._last_sent.clear()
    client.post("/v1/auth/phone/send", json={"phone": phone})
    res = client.post(
        "/v1/auth/phone/verify",
        json={"phone": phone, "code": "123456", "purpose": purpose},
    )
    assert res.status_code == 200
    token = res.json()["phone_verified_token"]
    assert token
    return token


def test_login_legacy_qc_password():
    res = client.post(
        "/v1/auth/login",
        json={"email": "seeker-0001@qc.iljari.co.kr", "password": "QcTest1234!"},
    )
    assert res.status_code == 200
    data = res.json()
    assert "access_token" in data
    token = data["access_token"]

    me = client.get("/v1/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == "seeker-0001@qc.iljari.co.kr"


def test_phone_verify_mock_returns_token():
    send = client.post("/v1/auth/phone/send", json={"phone": "01012345678"})
    assert send.status_code == 200
    assert send.json()["mock"] is True

    verify = client.post(
        "/v1/auth/phone/verify",
        json={"phone": "01012345678", "code": "123456", "purpose": "signup"},
    )
    assert verify.status_code == 200
    body = verify.json()
    assert body["verified"] is True
    assert body["phone_verified_token"]


def test_phone_send_reuses_pending_code_without_error():
    phone = "01055557777"
    phone_svc._store.clear()
    phone_svc._last_sent.clear()
    first = client.post("/v1/auth/phone/send", json={"phone": phone})
    assert first.status_code == 200
    assert first.json()["sms_sent"] is True
    second = client.post("/v1/auth/phone/send", json={"phone": phone})
    assert second.status_code == 200
    assert second.json()["sms_sent"] is False


def test_phone_send_allowed_immediately_after_verify():
    phone = "01055558888"
    phone_svc._store.clear()
    phone_svc._last_sent.clear()
    client.post("/v1/auth/phone/send", json={"phone": phone})
    verify = client.post(
        "/v1/auth/phone/verify",
        json={"phone": phone, "code": "123456", "purpose": "signup"},
    )
    assert verify.status_code == 200
    again = client.post("/v1/auth/phone/send", json={"phone": phone})
    assert again.status_code == 200
    assert again.json()["sms_sent"] is True


def test_phone_send_rejects_misconfigured_provider_instead_of_faking_success():
    """SMS_PROVIDER 오타·대소문자 불일치 시, 문자를 보내지 않고도 발송 성공으로
    응답하던 조용한 실패를 막는다 — 명확한 400 에러여야 한다."""
    phone = "01055559999"
    phone_svc._store.clear()
    phone_svc._last_sent.clear()
    with patch.object(settings, "sms_provider", "Aligo"), patch.object(
        settings, "sms_api_key", "dummy-key"
    ):
        res = client.post("/v1/auth/phone/send", json={"phone": phone})
    assert res.status_code == 400
    assert phone_svc._normalize(phone) not in phone_svc._store


def test_signup_login_find_email_reset_password():
    phone = f"010{uuid4().int % 10**8:08d}"
    email = f"newseeker-{uuid4().hex[:8]}@example.com"
    signup_token = _verify_phone(phone, purpose="signup")

    signup = client.post(
        "/v1/auth/signup",
        json={
            "email": email,
            "password": "SecurePass1!",
            "phone": phone,
            "phone_verified_token": signup_token,
            "display_name": "신규구직",
            "seeker_profile": {"phoneVerified": True},
        },
    )
    assert signup.status_code == 200, signup.text
    assert signup.json()["email"] == email

    bad_login = client.post(
        "/v1/auth/login",
        json={"email": email, "password": "wrong"},
    )
    assert bad_login.status_code == 401

    login = client.post(
        "/v1/auth/login",
        json={"email": email, "password": "SecurePass1!"},
    )
    assert login.status_code == 200
    token = login.json()["access_token"]

    patch = client.patch(
        "/v1/auth/me/seeker-profile",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "display_name": "최영진",
            "seeker_profile": {
                "phoneVerified": True,
                "homeRoadAddress": "경기 용인시 수지구",
                "preferredRegions": ["경기 용인시"],
            },
        },
    )
    assert patch.status_code == 200, patch.text
    body = patch.json()
    assert body["display_name"] == "최영진"
    assert body["seeker_profile"]["homeRoadAddress"] == "경기 용인시 수지구"

    find_token = _verify_phone(phone, purpose="find_email")
    found = client.post(
        "/v1/auth/account/find-email",
        json={"phone": phone, "phone_verified_token": find_token},
    )
    assert found.status_code == 200
    emails = found.json()["masked_emails"]
    assert emails
    assert "@" in emails[0]

    reset_token = _verify_phone(phone, purpose="reset_password")
    reset = client.post(
        "/v1/auth/password/reset",
        json={
            "email": email,
            "phone": phone,
            "phone_verified_token": reset_token,
            "new_password": "NewSecure2!",
        },
    )
    assert reset.status_code == 200

    login2 = client.post(
        "/v1/auth/login",
        json={"email": email, "password": "NewSecure2!"},
    )
    assert login2.status_code == 200


def test_signup_rejects_weak_password():
    phone = "01011112223"
    token = _verify_phone(phone)
    res = client.post(
        "/v1/auth/signup",
        json={
            "email": "weak@example.com",
            "password": "short",
            "phone": phone,
            "phone_verified_token": token,
            "display_name": "약한비번",
        },
    )
    assert res.status_code == 400


def test_corporate_signup_login_cross_device():
    email = f"corp-{uuid4().hex[:8]}@example.com"
    phone = f"010{uuid4().int % 10**8:08d}"
    company_key = normalize_brn(f"1234567{uuid4().int % 1000:03d}")
    signup_token = _verify_phone(phone, purpose="signup")
    handler_code = f"{1000 + uuid4().int % 8999}"
    signup = client.post(
        "/v1/auth/signup/corporate",
        json={
            "email": email,
            "password": "SecurePass1!",
            "display_name": "김담당",
            "phone": phone,
            "phone_verified_token": signup_token,
            "company_name": "테스트물류",
            "company_key": company_key,
            "department": "인사팀",
            "contact_person_name": "김담당",
            "handler_code": handler_code,
        },
    )
    assert signup.status_code == 200, signup.text
    data = signup.json()
    assert data["member_type"] == "corporate"
    assert data["company_key"] == company_key
    assert data["handler_code"] == handler_code

    login = client.post(
        "/v1/auth/login",
        json={"email": email, "password": "SecurePass1!"},
    )
    assert login.status_code == 200
    assert login.json()["company_name"] == "테스트물류"
