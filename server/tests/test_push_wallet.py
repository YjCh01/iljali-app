from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-wallet@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_wallet_get_and_claim_bonus():
    key = "1234567890"
    headers = _employer_headers(key)
    r = client.get(f"/v1/wallet/{key}", headers=headers)
    assert r.status_code == 200
    assert r.json()["company_key"] == key
    assert r.json()["available_push_credits"] >= 1

    claim = client.post(f"/v1/wallet/{key}/bonus/claim", headers=headers)
    assert claim.status_code == 200
    assert claim.json()["claimed"] is True
    assert claim.json()["granted_pushes"] == 2

    wallet = client.get(f"/v1/wallet/{key}", headers=headers).json()
    assert wallet["signup_bonus_remaining"] == 2

    again = client.post(f"/v1/wallet/{key}/bonus/claim", headers=headers)
    assert again.json()["claimed"] is False


def test_add_package_credits():
    key = "9876543210"
    r = client.post(
        f"/v1/wallet/{key}/credits",
        json={"count": 3, "location_slots": 3},
        headers={"X-Admin-Api-Key": settings.admin_api_key},
    )
    assert r.status_code == 200
    assert r.json()["package_credits"] == 3
    assert r.json()["location_slots_from_packages"] == 3
