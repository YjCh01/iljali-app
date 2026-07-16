from fastapi.testclient import TestClient

from app.credential_models import CredentialDefinitionRow
from app.database import Base, SessionLocal, engine
from app.main import app
from app.services.credential_service import seed_credential_catalog_if_empty

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)
    # 다른 테스트 모듈이 drop_all을 호출했을 수 있으므로(공유 스키마) 명시적으로
    # 재시드 — 실제 운영에서는 /catalog 엔드포인트 자체가 자체 치유한다.
    db = SessionLocal()
    try:
        seed_credential_catalog_if_empty(db)
    finally:
        db.close()


def test_catalog_is_seeded_on_startup():
    db = SessionLocal()
    try:
        count = db.query(CredentialDefinitionRow).count()
    finally:
        db.close()
    assert count == 15


def test_catalog_endpoint_returns_seeded_items_in_order():
    response = client.get("/v1/credentials/catalog")
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 15
    assert items[0]["id"] == "construction_safety_basic"
    assert items[-1]["id"] == "health_certificate"

    health = next(i for i in items if i["id"] == "health_certificate")
    assert health["requires_photo"] is True
    assert "보건증" in health["aliases"]

    consent = next(i for i in items if i["id"] == "criminal_record_consent")
    assert consent["requires_photo"] is False
    assert consent["guide_document_id"] == "criminal_record_consent"


def test_seeding_is_idempotent():
    db = SessionLocal()
    try:
        from app.services.credential_service import seed_credential_catalog_if_empty

        seed_credential_catalog_if_empty(db)
        count = db.query(CredentialDefinitionRow).count()
    finally:
        db.close()
    assert count == 15
