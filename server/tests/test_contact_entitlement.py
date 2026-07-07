from app.models import Company
from app.services.entitlement_service import evaluate_contact


def test_evaluate_contact_allows_basic_company():
    company = Company(
        company_key="1234567890",
        company_name="테스트",
        entity_type="corporation",
        partnership_tier="basic",
        monthly_subscription_active=False,
        requires_admin_review=True,
        admin_review_approved=False,
    )
    result = evaluate_contact(None, company)
    assert result["allowed"] is True
    assert result["show_partnership_upsell"] is False


def test_evaluate_contact_blocks_suspended_company():
    company = Company(
        company_key="1234567890",
        company_name="테스트",
        entity_type="corporation",
        is_suspended=True,
    )
    result = evaluate_contact(None, company)
    assert result["allowed"] is False
    assert "정지" in result["block_reason"]
