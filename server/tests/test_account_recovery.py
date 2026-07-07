"""계정 찾기·복구 서비스 테스트."""

from uuid import uuid4

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.qc_models import QcMemberRow
from app.services import phone_verify_service as phone_svc
from app.services.entitlement_service import normalize_brn

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_corporate_find_email_by_brn():
    brn = normalize_brn("9876543210")
    email = f"corp-find-{uuid4().hex[:6]}@example.com"
    db = SessionLocal()
    try:
        db.add(
            QcMemberRow(
                id=f"qc_{uuid4().hex[:12]}",
                email=email,
                display_name="박담당",
                member_type="corporate",
                company_key=brn,
                company_name="찾기테스트",
                contact_person_name="박담당",
                password_hash="x",
            )
        )
        db.commit()
    finally:
        db.close()

    found = client.post(
        "/v1/auth/account/find-email/corporate",
        json={
            "method": "brn",
            "contact_person_name": "박담당",
            "company_key": brn,
        },
    )
    assert found.status_code == 200, found.text
    emails = found.json()["masked_emails"]
    assert emails
    assert "@" in emails[0]
