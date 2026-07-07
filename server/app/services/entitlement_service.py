from sqlalchemy.orm import Session

from app.models import Company


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
    """지원자 연락·채팅 — 기본 플랜 포함. 계정 정지만 차단."""
    if company.is_suspended:
        return {
            "allowed": False,
            "block_reason": "계정이 정지되었습니다.",
            "show_partnership_upsell": False,
        }
    return {"allowed": True, "show_partnership_upsell": False}


def increment_contact(db: Session, company_key: str) -> None:
    """BASIC 완전 차단 정책 — 카운트 증가 없음 (감사 로그는 contact_events에 별도 기록)."""
    return
