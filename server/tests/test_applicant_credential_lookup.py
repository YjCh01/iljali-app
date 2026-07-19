import json

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.qc_models import QcMemberRow
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "5055055055"
OTHER_COMPANY_KEY = "6066066066"
SEEKER_EMAIL = "seeker-cred-lookup-1@test.iljari.co.kr"


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        row = db.query(QcMemberRow).filter(QcMemberRow.email == SEEKER_EMAIL).first()
        if row is None:
            row = QcMemberRow(
                id="qc_seeker_cred_lookup_1",
                email=SEEKER_EMAIL,
                display_name="자격증조회테스트",
                member_type="seeker",
                phone="01099998888",
            )
            db.add(row)
        row.seeker_profile_json = json.dumps(
            {
                "credentialHoldings": [
                    {
                        "credentialId": "forklift_operator_cert",
                        "imagePath": "https://cdn.test/forklift.jpg",
                    },
                    {
                        "credentialId": "health_certificate",
                        "imagePath": "https://cdn.test/health.jpg",
                    },
                    {"credentialId": "no_photo_cert"},
                ]
            }
        )
        db.commit()
    finally:
        db.close()


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-cred-lookup@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _submit_application(*, status: str, post_id: str) -> str:
    created = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": post_id,
            "company_key": COMPANY_KEY,
            "seeker_email": SEEKER_EMAIL,
            "status": status,
        },
        headers=_employer_headers(COMPANY_KEY),
    )
    assert created.status_code == 200
    return created.json()["id"]


def test_employer_sees_held_flag_but_not_photo_before_confirmation():
    application_id = _submit_application(status="applied", post_id="post-cl-1")

    response = client.get(
        f"/v1/credentials/applicants/{application_id}/credentials",
        headers=_employer_headers(COMPANY_KEY),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["can_view_documents"] is False

    holdings = {h["credentialId"]: h for h in body["holdings"]}
    assert holdings["forklift_operator_cert"]["has_photo"] is True
    assert "imagePath" not in holdings["forklift_operator_cert"]
    assert holdings["no_photo_cert"]["has_photo"] is False


def test_employer_sees_photo_after_hire_confirmed():
    application_id = _submit_application(status="scheduled", post_id="post-cl-2")

    response = client.get(
        f"/v1/credentials/applicants/{application_id}/credentials",
        headers=_employer_headers(COMPANY_KEY),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["can_view_documents"] is True

    holdings = {h["credentialId"]: h for h in body["holdings"]}
    assert holdings["forklift_operator_cert"]["has_photo"] is True
    assert holdings["forklift_operator_cert"]["imagePath"] == (
        "https://cdn.test/forklift.jpg"
    )


def test_other_company_cannot_view_applicant_credentials():
    application_id = _submit_application(status="applied", post_id="post-cl-3")

    response = client.get(
        f"/v1/credentials/applicants/{application_id}/credentials",
        headers=_employer_headers(OTHER_COMPANY_KEY),
    )
    assert response.status_code == 403


def test_unknown_application_returns_404():
    response = client.get(
        "/v1/credentials/applicants/does-not-exist/credentials",
        headers=_employer_headers(COMPANY_KEY),
    )
    assert response.status_code == 404


def test_works_regardless_of_seeker_login_state():
    # 이 테스트는 구직자 세션/토큰 없이(고용주 토큰만으로) 조회가 되는지만 확인 —
    # 기기·로그인 상태와 무관하게 서버 DB에서 바로 조회되는 게 D4의 핵심.
    application_id = _submit_application(status="applied", post_id="post-cl-4")

    response = client.get(
        f"/v1/credentials/applicants/{application_id}/credentials",
        headers=_employer_headers(COMPANY_KEY),
    )
    assert response.status_code == 200
    assert response.json()["seeker_email"] == SEEKER_EMAIL
