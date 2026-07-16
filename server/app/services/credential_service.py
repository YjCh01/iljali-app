"""자격증 표준 카탈로그 조회 + 지원자 보유 자격증 조회."""

from __future__ import annotations

import json

from sqlalchemy.orm import Session

from app.credential_models import SEED_CREDENTIAL_DEFINITIONS, CredentialDefinitionRow


def seed_credential_catalog_if_empty(db: Session) -> None:
    if db.query(CredentialDefinitionRow).first() is not None:
        return
    for index, (
        cred_id,
        label,
        category,
        aliases,
        requires_photo,
        summary,
        guide_document_id,
    ) in enumerate(SEED_CREDENTIAL_DEFINITIONS):
        db.add(
            CredentialDefinitionRow(
                id=cred_id,
                label=label,
                category=category,
                aliases_json=json.dumps(aliases, ensure_ascii=False),
                requires_photo=requires_photo,
                summary=summary,
                guide_document_id=guide_document_id,
                active=True,
                sort_order=index,
            )
        )
    db.commit()


def _row_to_dict(row: CredentialDefinitionRow) -> dict:
    try:
        aliases = json.loads(row.aliases_json or "[]")
    except json.JSONDecodeError:
        aliases = []
    return {
        "id": row.id,
        "label": row.label,
        "category": row.category,
        "aliases": aliases,
        "requires_photo": row.requires_photo,
        "summary": row.summary,
        "guide_document_id": row.guide_document_id,
    }


def list_credential_catalog(db: Session) -> list[dict]:
    rows = (
        db.query(CredentialDefinitionRow)
        .filter(CredentialDefinitionRow.active.is_(True))
        .order_by(CredentialDefinitionRow.sort_order.asc())
        .all()
    )
    return [_row_to_dict(r) for r in rows]
