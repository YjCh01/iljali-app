"""아이디·비밀번호 찾기 공통 로직."""

from __future__ import annotations

from sqlalchemy.orm import Session

from app.qc_models import QcMemberRow
from app.services.entitlement_service import normalize_brn
from app.services.password_service import mask_email


def _normalize_person_name(value: str) -> str:
    return value.strip().replace(" ", "")


def _person_name_matches(row: QcMemberRow, expected: str) -> bool:
    target = _normalize_person_name(expected)
    if not target:
        return False
    for candidate in (row.display_name, row.contact_person_name):
        if candidate and _normalize_person_name(candidate) == target:
            return True
    return False


def find_seeker_emails(
    db: Session,
    *,
    phone: str,
    display_name: str,
) -> list[str]:
    rows = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.phone == phone)
        .filter(QcMemberRow.member_type == "seeker")
        .order_by(QcMemberRow.created_at.desc())
        .all()
    )
    matched = [row for row in rows if _person_name_matches(row, display_name)]
    return [mask_email(row.email) for row in matched]


def find_seeker_emails_by_email(
    db: Session,
    *,
    email: str,
    display_name: str,
) -> list[str]:
    row = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    if row is None or not _person_name_matches(row, display_name):
        return []
    return [mask_email(row.email)]


def find_corporate_emails(
    db: Session,
    *,
    company_key: str,
    contact_person_name: str,
) -> list[str]:
    brn = normalize_brn(company_key)
    rows = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.company_key == brn)
        .filter(QcMemberRow.member_type.in_(["corporate", "employer"]))
        .order_by(QcMemberRow.created_at.desc())
        .all()
    )
    matched = [
        row for row in rows if _person_name_matches(row, contact_person_name)
    ]
    return [mask_email(row.email) for row in matched]


def find_corporate_emails_by_email(
    db: Session,
    *,
    email: str,
    contact_person_name: str,
) -> list[str]:
    row = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.member_type.in_(["corporate", "employer"]))
        .first()
    )
    if row is None or not _person_name_matches(row, contact_person_name):
        return []
    return [mask_email(row.email)]


def reset_seeker_password(
    db: Session,
    *,
    email: str,
    phone: str,
    display_name: str,
    password_hash: str,
) -> QcMemberRow | None:
    row = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.phone == phone)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    if row is None or not _person_name_matches(row, display_name):
        return None
    row.password_hash = password_hash
    return row


def reset_seeker_password_by_email(
    db: Session,
    *,
    email: str,
    display_name: str,
    password_hash: str,
) -> QcMemberRow | None:
    row = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    if row is None or not _person_name_matches(row, display_name):
        return None
    row.password_hash = password_hash
    return row


def reset_corporate_password(
    db: Session,
    *,
    email: str,
    phone: str,
    contact_person_name: str,
    password_hash: str,
) -> QcMemberRow | None:
    row = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.phone == phone)
        .filter(QcMemberRow.member_type.in_(["corporate", "employer"]))
        .first()
    )
    if row is None or not _person_name_matches(row, contact_person_name):
        return None
    row.password_hash = password_hash
    return row


def reset_corporate_password_by_email(
    db: Session,
    *,
    email: str,
    contact_person_name: str,
    password_hash: str,
) -> QcMemberRow | None:
    row = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == email)
        .filter(QcMemberRow.member_type.in_(["corporate", "employer"]))
        .first()
    )
    if row is None or not _person_name_matches(row, contact_person_name):
        return None
    row.password_hash = password_hash
    return row
