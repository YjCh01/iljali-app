from fastapi.testclient import TestClient

from app.config import settings
from app.database import Base, SessionLocal, engine
from app.main import app
from app.push_wallet_models import EmployerPushWalletRow
from app.qc_models import AdminAuditLogRow, JobPostEntitlementRow
from app.services.admin_grant_revoke_service import revoke_admin_grants
from app.services.admin_ops_service import grant_wallet_credits, upsert_job_pin_entitlement

client = TestClient(app)
ADMIN_HEADERS = {"X-Admin-Api-Key": settings.admin_api_key}


def setup_module():
    Base.metadata.create_all(bind=engine)


def teardown_module():
    Base.metadata.drop_all(bind=engine)


def test_revoke_admin_wallet_and_entitlement():
    db = SessionLocal()
    try:
        grant_wallet_credits(
            db,
            company_key="5403100894",
            package_credits=5,
            push_ticket_credits=3,
        )
        upsert_job_pin_entitlement(
            db,
            post_id="real_post_001",
            recruitment_pin_active=True,
        )

        preview = revoke_admin_grants(db, dry_run=True)
        assert preview["wallet_companies"] == 1
        assert preview["entitlement_posts"] == 1

        wallet = db.get(EmployerPushWalletRow, "5403100894")
        assert wallet.package_credits == 5
        assert wallet.push_ticket_credits == 3

        result = revoke_admin_grants(db, dry_run=False)
        assert result["wallet_companies"] == 1

        wallet = db.get(EmployerPushWalletRow, "5403100894")
        assert wallet.package_credits == 0
        assert wallet.push_ticket_credits == 0
        assert wallet.location_slots_from_packages == 0

        ent = db.get(JobPostEntitlementRow, "real_post_001")
        assert ent.recruitment_pin_active is False
        assert ent.map_pin_tier == ""

        audit = (
            db.query(AdminAuditLogRow)
            .filter(AdminAuditLogRow.action == "wallet.revoke_admin_grants")
            .one()
        )
        assert '"wallet_companies": 1' in audit.detail_json
    finally:
        db.close()


def test_revoke_admin_grants_api_dry_run():
    r = client.post(
        "/v1/admin/ops/wallet/revoke-admin-grants?dry_run=true",
        headers=ADMIN_HEADERS,
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["dry_run"] is True
