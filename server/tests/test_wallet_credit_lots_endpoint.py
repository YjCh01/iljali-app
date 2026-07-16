from datetime import datetime, timedelta

from fastapi.testclient import TestClient

from app.database import Base, SessionLocal, engine
from app.main import app
from app.push_wallet_models import PushWalletCreditLotRow
from app.services.push_wallet_service import get_or_create_wallet, grant_credit_lot

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def test_lots_endpoint_lists_active_lots_soonest_expiry_first():
    company_key = "7010001111"
    db = SessionLocal()
    get_or_create_wallet(db, company_key)
    grant_credit_lot(
        db,
        company_key,
        "package",
        5,
        location_slots=5,
        source_order_id="LOT-A",
    )
    db.query(PushWalletCreditLotRow).filter(
        PushWalletCreditLotRow.source_order_id == "LOT-A"
    ).update({"expires_at": datetime.utcnow() + timedelta(days=30)})
    grant_credit_lot(
        db,
        company_key,
        "push_ticket",
        2,
        source_order_id="LOT-B",
    )
    db.query(PushWalletCreditLotRow).filter(
        PushWalletCreditLotRow.source_order_id == "LOT-B"
    ).update({"expires_at": datetime.utcnow() + timedelta(days=5)})
    db.commit()
    db.close()

    resp = client.get(f"/v1/wallet/{company_key}/lots")
    assert resp.status_code == 200
    body = resp.json()
    assert body["company_key"] == company_key
    lots = body["lots"]
    assert [lot["source_order_id"] for lot in lots] == ["LOT-B", "LOT-A"]
    assert lots[0]["remaining"] == 2
    assert lots[1]["remaining"] == 5


def test_lots_endpoint_excludes_swept_expired_lots():
    company_key = "7010002222"
    db = SessionLocal()
    wallet = get_or_create_wallet(db, company_key)
    wallet.package_credits = 3
    wallet.location_slots_from_packages = 3
    db.add(
        PushWalletCreditLotRow(
            company_key=company_key,
            credit_type="package",
            count=3,
            remaining=3,
            expires_at=datetime.utcnow() - timedelta(days=1),
            source_order_id="EXPIRED-LOT",
        )
    )
    db.commit()
    db.close()

    resp = client.get(f"/v1/wallet/{company_key}/lots")
    assert resp.status_code == 200
    assert resp.json()["lots"] == []


def test_lots_endpoint_empty_for_new_company():
    resp = client.get("/v1/wallet/7010003333/lots")
    assert resp.status_code == 200
    assert resp.json()["lots"] == []
