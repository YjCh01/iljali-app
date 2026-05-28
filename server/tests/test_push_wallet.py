from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def test_wallet_get_and_claim_bonus():
    key = "1234567890"
    r = client.get(f"/v1/wallet/{key}")
    assert r.status_code == 200
    assert r.json()["company_key"] == key
    assert r.json()["available_push_credits"] >= 1

    claim = client.post(f"/v1/wallet/{key}/bonus/claim")
    assert claim.status_code == 200
    assert claim.json()["claimed"] is True
    assert claim.json()["granted_pushes"] == 5

    wallet = client.get(f"/v1/wallet/{key}").json()
    assert wallet["signup_bonus_remaining"] == 5

    again = client.post(f"/v1/wallet/{key}/bonus/claim")
    assert again.json()["claimed"] is False


def test_add_package_credits():
    key = "9876543210"
    r = client.post(
        f"/v1/wallet/{key}/credits",
        json={"count": 3, "location_slots": 3},
    )
    assert r.status_code == 200
    assert r.json()["package_credits"] == 3
    assert r.json()["location_slots_from_packages"] == 3
