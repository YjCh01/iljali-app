import io

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.main import app
from app.models import Company
from app.services.auth_token_service import issue_token

client = TestClient(app)

COMPANY_KEY = "7077077077"


def setup_module():
    Base.metadata.create_all(bind=engine)


def _employer_headers(company_key: str = COMPANY_KEY) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-cert@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_upload_business_cert_media_requires_no_auth():
    # 가입 절차 도중(계정 생성 전) 호출되므로 인증 없이도 업로드가 가능해야 한다.
    response = client.post(
        "/v1/business-cert-media/upload",
        files={"file": ("cert.jpg", io.BytesIO(b"fake-cert-bytes"), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert "/media/business-cert/" in body["url"]

    relative = "/" + body["url"].split("/", 3)[3]
    fetched = client.get(relative)
    assert fetched.status_code == 200
    assert fetched.content == b"fake-cert-bytes"


def test_upload_rejects_disallowed_extension():
    response = client.post(
        "/v1/business-cert-media/upload",
        files={"file": ("cert.pdf", io.BytesIO(b"fake-pdf"), "application/pdf")},
    )
    assert response.status_code == 400


def test_resubmit_certificate_sets_admin_review_required():
    db = SessionLocal()
    try:
        db.add(
            Company(
                company_key=COMPANY_KEY,
                company_name="테스트기업",
                verification_status="verified",
                requires_admin_review=False,
                admin_review_approved=True,
            )
        )
        db.commit()
    finally:
        db.close()

    response = client.post(
        f"/v1/compliance/business/{COMPANY_KEY}/resubmit-certificate",
        headers=_employer_headers(),
        json={
            "certificate_image_ref": "https://api.test/media/business-cert/new.jpg",
            "note": "더 선명한 사진으로 재업로드",
        },
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["status"] == "adminReviewRequired"
    assert body["requires_admin_review"] is True
    assert body["certificate_image_ref"] == (
        "https://api.test/media/business-cert/new.jpg"
    )
    assert body["admin_review_reason"] == "더 선명한 사진으로 재업로드"

    admin_view = client.get(
        f"/v1/admin/ops/companies/{COMPANY_KEY}/verification",
        headers={"X-Admin-Api-Key": settings.admin_api_key},
    )
    assert admin_view.status_code == 200
    assert admin_view.json()["certificate_image_ref"] == (
        "https://api.test/media/business-cert/new.jpg"
    )


def test_resubmit_certificate_rejects_other_company():
    response = client.post(
        f"/v1/compliance/business/{COMPANY_KEY}/resubmit-certificate",
        headers=_employer_headers(company_key="8088088088"),
        json={"certificate_image_ref": "https://api.test/media/business-cert/x.jpg"},
    )
    assert response.status_code == 403


def test_resubmit_certificate_requires_auth():
    response = client.post(
        f"/v1/compliance/business/{COMPANY_KEY}/resubmit-certificate",
        json={"certificate_image_ref": "https://api.test/media/business-cert/x.jpg"},
    )
    assert response.status_code == 401
