from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.main import app
from app.push_wallet_models import PushWalletCreditLotRow
from app.services.auth_token_service import issue_token
from app.services.push_wallet_service import get_or_create_wallet, grant_credit_lot

client = TestClient(app)

_ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-consume@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def test_consume_decrements_balance():
    company_key = "1212121212"
    client.post(
        f"/v1/wallet/{company_key}/credits",
        json={"count": 5, "location_slots": 5, "credit_type": "package"},
        headers=_ADMIN_HEADERS,
    )
    response = client.post(
        f"/v1/wallet/{company_key}/consume",
        json={"credit_type": "package", "count": 2},
        headers=_employer_headers(company_key),
    )
    assert response.status_code == 200
    assert response.json()["package_credits"] == 3
    assert response.json()["location_slots_from_packages"] == 3


def test_consume_rejects_insufficient_balance():
    company_key = "1313131313"
    client.post(
        f"/v1/wallet/{company_key}/credits",
        json={"count": 1, "credit_type": "push_ticket"},
        headers=_ADMIN_HEADERS,
    )
    response = client.post(
        f"/v1/wallet/{company_key}/consume",
        json={"credit_type": "push_ticket", "count": 5},
        headers=_employer_headers(company_key),
    )
    assert response.status_code == 402

    wallet = client.get(
        f"/v1/wallet/{company_key}", headers=_employer_headers(company_key)
    ).json()
    assert wallet["push_ticket_credits"] == 1


def test_consume_is_fifo_across_lots_and_spares_newer_lot_from_expiry():
    """오래된 lot부터 소비하면, 나중에 그 lot이 만료돼도 이미 소비된 만큼은 잔액에서
    중복 차감되지 않는다."""
    company_key = "1414141414"
    db = SessionLocal()
    old_lot = PushWalletCreditLotRow(
        company_key=company_key,
        credit_type="package",
        count=5,
        remaining=5,
        granted_at=datetime.utcnow() - timedelta(days=10),
        expires_at=datetime.utcnow() + timedelta(days=1),
    )
    new_lot = PushWalletCreditLotRow(
        company_key=company_key,
        credit_type="package",
        count=5,
        remaining=5,
        granted_at=datetime.utcnow(),
        expires_at=datetime.utcnow() + timedelta(days=180),
    )
    db.add(old_lot)
    db.add(new_lot)
    wallet = get_or_create_wallet(db, company_key)
    wallet.package_credits = 10
    wallet.location_slots_from_packages = 10
    db.commit()
    old_lot_id = old_lot.id
    new_lot_id = new_lot.id
    db.close()

    # 6개 소비 — old_lot(5) 전부 + new_lot에서 1개만 차감돼야 함
    response = client.post(
        f"/v1/wallet/{company_key}/consume",
        json={"credit_type": "package", "count": 6},
        headers=_employer_headers(company_key),
    )
    assert response.status_code == 200
    assert response.json()["package_credits"] == 4

    db = SessionLocal()
    refreshed_old = db.get(PushWalletCreditLotRow, old_lot_id)
    refreshed_new = db.get(PushWalletCreditLotRow, new_lot_id)
    assert refreshed_old.remaining == 0
    assert refreshed_new.remaining == 4
    db.close()

    # old_lot을 강제로 만료시켜도(이미 remaining=0) 더 이상 뺄 게 없어야 함
    db = SessionLocal()
    lot = db.get(PushWalletCreditLotRow, old_lot_id)
    lot.expires_at = datetime.utcnow() - timedelta(seconds=1)
    db.commit()
    db.close()

    wallet_after_sweep = client.get(
        f"/v1/wallet/{company_key}", headers=_employer_headers(company_key)
    ).json()
    assert wallet_after_sweep["package_credits"] == 4


def test_consume_falls_back_to_legacy_balance_without_lots():
    """lot 도입 이전 잔액(legacy, lot 레코드 없음)도 정상 소비된다."""
    company_key = "1515151515"
    db = SessionLocal()
    wallet = get_or_create_wallet(db, company_key)
    wallet.package_credits = 4
    wallet.location_slots_from_packages = 4
    db.commit()
    db.close()

    response = client.post(
        f"/v1/wallet/{company_key}/consume",
        json={"credit_type": "package", "count": 3},
        headers=_employer_headers(company_key),
    )
    assert response.status_code == 200
    assert response.json()["package_credits"] == 1
