from fastapi.testclient import TestClient

from app.database import Base, engine
from app.main import app
from app.services.auth_token_service import issue_token
from app.services.nts_service import NtsLookupResult

client = TestClient(app)


def setup_module():
    Base.metadata.create_all(bind=engine)


def _employer_headers(company_key: str) -> dict[str, str]:
    token = issue_token(
        {
            "sub": "corp-verification@test.iljari.co.kr",
            "member_type": "corporate",
            "company_key": company_key,
        }
    )
    return {"Authorization": f"Bearer {token}"}


def _stub_nts(monkeypatch, *, industry_name: str) -> None:
    """실제 국세청 API 호출 없이 조회 결과를 고정 — NTS_API_KEY가 설정된 환경에서도
    이 테스트가 네트워크에 의존하지 않도록 함."""

    async def fake_verify_business(self, brn, company_name, **kwargs):
        return NtsLookupResult(
            valid=True,
            company_name=company_name,
            industry_name=industry_name,
            business_status="continuing",
            business_status_code="01",
            entity_type_label="법인",
            api_source="stub",
        )

    monkeypatch.setattr(
        "app.routers.compliance.NtsService.verify_business", fake_verify_business
    )


def test_verified_business_grants_bonus_once(monkeypatch):
    _stub_nts(monkeypatch, industry_name="화물운송 및 물류대행")
    brn = "8010102221"
    body = {
        "company_name": "테스트물류",
        "business_registration_number": brn,
        "entity_type": "corporation",
    }
    first = client.post("/v1/compliance/business/verify", json=body)
    assert first.status_code == 200
    assert first.json()["status"] == "verified"

    wallet = client.get(f"/v1/wallet/{brn}", headers=_employer_headers(brn)).json()
    assert wallet["package_credits"] == 5
    assert wallet["location_slots_from_packages"] == 5

    # 재인증(재조회) 해도 중복 지급되지 않음
    second = client.post("/v1/compliance/business/verify", json=body)
    assert second.status_code == 200
    wallet_after = client.get(
        f"/v1/wallet/{brn}", headers=_employer_headers(brn)
    ).json()
    assert wallet_after["package_credits"] == 5


def test_admin_review_required_business_does_not_grant_bonus(monkeypatch):
    _stub_nts(monkeypatch, industry_name="인력공급업")
    brn = "8010188882"
    body = {
        "company_name": "아웃소싱테스트",
        "business_registration_number": brn,
        "entity_type": "corporation",
    }
    response = client.post("/v1/compliance/business/verify", json=body)
    assert response.status_code == 200
    assert response.json()["status"] == "adminReviewRequired"

    wallet = client.get(f"/v1/wallet/{brn}", headers=_employer_headers(brn)).json()
    assert wallet["package_credits"] == 0
