from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.qc_models import MemberSocialLinkRow, QcMemberRow
from app.database import SessionLocal
from app.services.auth_token_service import (
    issue_phone_verified_token,
    issue_social_signup_token,
)

client = TestClient(app)

COMPANY_KEY = "9099099099"
PHONE = "01055512345"


def setup_module():
    Base.metadata.create_all(bind=engine)


def _social_token(
    *,
    email: str,
    member_type: str = "corporate",
    provider_user_id: str = "kakao_uid_1",
) -> str:
    return issue_social_signup_token(
        provider="kakao",
        provider_user_id=provider_user_id,
        email=email,
        display_name="김담당",
        member_type=member_type,
    )


def _phone_token(phone: str = PHONE) -> str:
    return issue_phone_verified_token(phone, purpose="signup")


def test_corporate_social_signup_creates_account_without_client_supplied_password():
    email = "corp-social-1@test.iljari.co.kr"
    response = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(email=email),
            "phone": PHONE,
            "phone_verified_token": _phone_token(),
            "display_name": "김담당",
            "company_name": "테스트 주식회사",
            "company_key": COMPANY_KEY,
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["email"] == email
    assert body["member_type"] == "corporate"
    assert body["company_key"] == COMPANY_KEY
    assert "access_token" in body

    db = SessionLocal()
    try:
        row = db.query(QcMemberRow).filter(QcMemberRow.email == email).first()
        assert row is not None
        # 비밀번호는 서버가 임의 생성 — 요청 바디 어디에도 비밀번호 필드가 없었음.
        assert row.password_hash != ""
        link = (
            db.query(MemberSocialLinkRow)
            .filter(MemberSocialLinkRow.member_id == row.id)
            .first()
        )
        assert link is not None
        assert link.provider == "kakao"
    finally:
        db.close()


def test_corporate_social_signup_logs_in_existing_linked_account():
    email = "corp-social-2@test.iljari.co.kr"
    provider_user_id = "kakao_uid_2"
    first = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(
                email=email, provider_user_id=provider_user_id
            ),
            "phone": "01055512346",
            "phone_verified_token": _phone_token("01055512346"),
            "display_name": "이담당",
            "company_name": "재로그인 테스트",
            "company_key": "9199199199",
        },
    )
    assert first.status_code == 200
    first_member_id = first.json()["email"]

    # 같은 social_token은 1회용이므로, 이미 연결된 계정에 대해서는 새 social_signup 토큰으로도
    # provider+provider_user_id 매칭을 통해 재가입 없이 로그인 처리되어야 한다.
    second = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(
                email=email, provider_user_id=provider_user_id
            ),
            "phone": "01055512346",
            "phone_verified_token": _phone_token("01055512346"),
            "display_name": "이담당",
            "company_name": "재로그인 테스트",
            "company_key": "9199199199",
        },
    )
    assert second.status_code == 200
    assert second.json()["email"] == first_member_id


def test_corporate_social_signup_rejects_seeker_token():
    response = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(
                email="seeker-social@test.iljari.co.kr",
                member_type="seeker",
                provider_user_id="kakao_uid_3",
            ),
            "phone": "01055512347",
            "phone_verified_token": _phone_token("01055512347"),
            "display_name": "구직자",
            "company_name": "무관",
            "company_key": "9299299299",
        },
    )
    assert response.status_code == 400


def test_corporate_social_signup_rejects_duplicate_email():
    email = "corp-social-dup@test.iljari.co.kr"
    first = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(
                email=email, provider_user_id="kakao_uid_4"
            ),
            "phone": "01055512348",
            "phone_verified_token": _phone_token("01055512348"),
            "display_name": "박담당",
            "company_name": "중복 테스트",
            "company_key": "9399399399",
        },
    )
    assert first.status_code == 200

    second = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(
                email=email, provider_user_id="kakao_uid_5"
            ),
            "phone": "01055512349",
            "phone_verified_token": _phone_token("01055512349"),
            "display_name": "박담당2",
            "company_name": "중복 테스트2",
            "company_key": "9499499499",
        },
    )
    assert second.status_code == 409


def test_corporate_social_signup_rejects_expired_phone_token():
    response = client.post(
        "/v1/auth/social/corporate-signup",
        json={
            "social_token": _social_token(
                email="corp-social-badphone@test.iljari.co.kr",
                provider_user_id="kakao_uid_6",
            ),
            "phone": "01055512350",
            "phone_verified_token": "not-a-real-token",
            "display_name": "최담당",
            "company_name": "실패 테스트",
            "company_key": "9599599599",
        },
    )
    assert response.status_code == 400
