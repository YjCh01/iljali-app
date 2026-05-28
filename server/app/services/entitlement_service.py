from sqlalchemy.orm import Session

from app.models import Company, industry_requires_review

PAID_TIERS = {"starter", "growth", "enterprise"}

BASIC_CONTACT_BLOCK_REASON = (
    "BASIC 플랜은 푸시·공고 등록만 가능합니다. "
    "지원자 연락·채팅은 Starter 이상 파트너십 가입 후 이용할 수 있습니다."
)


def normalize_brn(value: str) -> str:
    return "".join(ch for ch in value if ch.isdigit())


def get_or_create_company(db: Session, brn: str, company_name: str, entity_type: str) -> Company:
    company = db.query(Company).filter(Company.company_key == brn).first()
    if company:
        return company
    company = Company(
        company_key=brn,
        company_name=company_name,
        entity_type=entity_type,
    )
    db.add(company)
    db.commit()
    db.refresh(company)
    return company


def evaluate_contact(db: Session, company: Company) -> dict:
    if company.is_suspended:
        return {
            "allowed": False,
            "block_reason": "계정이 정지되었습니다.",
            "show_partnership_upsell": False,
        }
    if company.requires_admin_review and not company.admin_review_approved:
        return {
            "allowed": False,
            "block_reason": company.admin_review_reason
            or "관리자 검토 중입니다. Enterprise 가입·승인 후 연락 기능이 활성화됩니다.",
            "show_partnership_upsell": True,
        }
    if company.partnership_tier in PAID_TIERS and company.monthly_subscription_active:
        return {"allowed": True, "show_partnership_upsell": False}

    return {
        "allowed": False,
        "block_reason": BASIC_CONTACT_BLOCK_REASON,
        "show_partnership_upsell": True,
    }


def increment_contact(db: Session, company_key: str) -> None:
    """BASIC 완전 차단 정책 — 카운트 증가 없음 (감사 로그는 contact_events에 별도 기록)."""
    return
