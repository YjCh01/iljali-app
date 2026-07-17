from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.qc_models import QcMemberRow
from app.services.push_dispatch_hooks import push_new_applicant
from app.services.push_notification_service import register_device_token

client = TestClient(app)

COMPANY_KEY = "7020001111"
EMPLOYER_EMAIL = "employer-newapp@qc.iljari.co.kr"


def setup_module():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        row = db.query(QcMemberRow).filter(QcMemberRow.email == EMPLOYER_EMAIL).first()
        if row is None:
            db.add(
                QcMemberRow(
                    id="qc_employer_newapp_1",
                    email=EMPLOYER_EMAIL,
                    display_name="테스트 기업",
                    member_type="corporate",
                    company_key=COMPANY_KEY,
                )
            )
            db.commit()
    finally:
        db.close()


def test_push_new_applicant_skips_when_no_employer_token():
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_newapp_2",
            "post_title": "테스트 공고 2",
            "company_name": "토큰없는 기업",
            "company_key": "7020002222",
            "seeker_email": "seeker-newapp-2@qc.iljari.co.kr",
            "seeker_name": "지원자2",
        },
    )
    assert resp.status_code == 200, resp.text
    db = SessionLocal()
    try:
        result = push_new_applicant(db, application_id=resp.json()["id"])
    finally:
        db.close()
    assert result == {"sent": 0, "skipped": "no_tokens"}


def test_push_new_applicant_attempts_delivery_when_employer_has_token():
    db = SessionLocal()
    try:
        register_device_token(
            db,
            member_email=EMPLOYER_EMAIL,
            member_type="corporate",
            fcm_token="tok_newapp_employer_1",
        )
        db.commit()
    finally:
        db.close()

    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_newapp_1",
            "post_title": "테스트 공고",
            "company_name": "테스트 기업",
            "company_key": COMPANY_KEY,
            "seeker_email": "seeker-newapp-1@qc.iljari.co.kr",
            "seeker_name": "지원자",
        },
    )
    assert resp.status_code == 200, resp.text
    application_id = resp.json()["id"]

    db = SessionLocal()
    try:
        result = push_new_applicant(db, application_id=application_id)
    finally:
        db.close()
    # fcm_service has no service-account credentials configured in tests, so
    # delivery itself fails — but reaching "failed=1" (not "skipped: no_tokens")
    # proves the hook found the employer's registered token and tried to send.
    assert result == {"sent": 0, "failed": 1}


def test_updating_existing_application_does_not_error():
    body = {
        "post_id": "post_newapp_3",
        "post_title": "테스트 공고 3",
        "company_name": "테스트 기업",
        "company_key": COMPANY_KEY,
        "seeker_email": "seeker-newapp-3@qc.iljari.co.kr",
        "seeker_name": "지원자3",
        "status": "applied",
    }
    first = client.post("/v1/hiring/applications", json=body)
    assert first.status_code == 200, first.text
    first_id = first.json()["id"]

    body["status"] = "scheduled"
    second = client.post("/v1/hiring/applications", json=body)
    assert second.status_code == 200, second.text
    assert second.json()["id"] == first_id
    assert second.json()["status"] == "scheduled"


def test_push_new_applicant_returns_not_found_for_unknown_application():
    db = SessionLocal()
    try:
        result = push_new_applicant(db, application_id="does_not_exist")
    finally:
        db.close()
    assert result == {"sent": 0, "skipped": "application_not_found"}
