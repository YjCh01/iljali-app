import json

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.qc_models import QcMemberRow
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_A = "5055055055"
COMPANY_B = "6066066066"
SEEKER_EMAIL = "seeker-no-show-1@test.iljari.co.kr"


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        row = db.query(QcMemberRow).filter(QcMemberRow.email == SEEKER_EMAIL).first()
        if row is None:
            db.add(
                QcMemberRow(
                    id="qc_seeker_no_show_1",
                    email=SEEKER_EMAIL,
                    display_name="노쇼테스트",
                    member_type="seeker",
                    phone="01012340000",
                )
            )
            db.commit()
    finally:
        db.close()


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-no-show@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _submit_application(*, post_id: str, company_key: str) -> str:
    created = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": post_id,
            "company_key": company_key,
            "seeker_email": SEEKER_EMAIL,
            "status": "scheduled",
        },
    )
    assert created.status_code == 200
    return created.json()["id"]


def test_mark_no_show_persists_status_and_accumulates_count():
    application_id = _submit_application(post_id="post-ns-1", company_key=COMPANY_A)

    response = client.post(
        f"/v1/hiring/applications/{application_id}/mark-no-show",
        headers=_employer_headers(COMPANY_A),
    )
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "no_show"
    assert body["seeker_no_show_count"] == 1


def test_other_company_sees_accumulated_no_show_count():
    # 회사 B는 별도 지원 건에 대해 같은 구직자의 노쇼 누적치를 조회만 함(자기 마킹 없이도 보임).
    application_id = _submit_application(post_id="post-ns-2", company_key=COMPANY_B)

    fetched = client.get(f"/v1/hiring/applications/{application_id}")
    assert fetched.status_code == 200
    assert fetched.json()["seeker_no_show_count"] == 1


def test_second_no_show_from_different_company_increments_further():
    application_id = _submit_application(post_id="post-ns-3", company_key=COMPANY_B)

    response = client.post(
        f"/v1/hiring/applications/{application_id}/mark-no-show",
        headers=_employer_headers(COMPANY_B),
    )
    assert response.status_code == 200
    assert response.json()["seeker_no_show_count"] == 2


def test_other_company_cannot_mark_no_show_on_application_they_do_not_own():
    application_id = _submit_application(post_id="post-ns-4", company_key=COMPANY_A)

    response = client.post(
        f"/v1/hiring/applications/{application_id}/mark-no-show",
        headers=_employer_headers(COMPANY_B),
    )
    assert response.status_code == 403


def test_mark_no_show_requires_auth():
    application_id = _submit_application(post_id="post-ns-5", company_key=COMPANY_A)

    response = client.post(
        f"/v1/hiring/applications/{application_id}/mark-no-show",
    )
    assert response.status_code == 401
