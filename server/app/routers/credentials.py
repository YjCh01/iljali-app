"""자격증 표준 카탈로그 + 지원자 보유 자격증 조회."""

import json

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.job_sync_models import JobApplicationRow
from app.qc_models import QcMemberRow
from app.routers.job_board import _assert_employer_company, _resolve_bearer
from app.services.credential_service import (
    list_credential_catalog,
    seed_credential_catalog_if_empty,
)

router = APIRouter(prefix="/v1/credentials", tags=["credentials"])

# 원본 열람(사진 URL 포함)이 허용되는 상태 — hiring_credential_access.dart와 동일 정책.
_ORIGINAL_DOCUMENT_VISIBLE_STATUSES = {
    "scheduled",
    "checked_in",
    "commission_paid",
}


@router.get("/catalog")
def get_credential_catalog(db: Session = Depends(get_db)):
    # 자체 치유 — 테이블이 비어 있으면(예: 재해빌드) 조회 시점에 다시 시드.
    seed_credential_catalog_if_empty(db)
    return {"items": list_credential_catalog(db)}


@router.get("/applicants/{application_id}/credentials")
def get_applicant_credentials(
    application_id: str,
    authorization: str | None = Header(default=None),
    db: Session = Depends(get_db),
):
    """지원자 보유 자격증 — 기기·로그인 상태와 무관하게 서버에서 직접 조회.

    이 회사에 실제로 지원한 사람인지(row 자체가 증거)와 요청자가 그 회사
    소속 고용주인지를 확인한 뒤에만 반환한다."""
    payload = _resolve_bearer(authorization)
    application = db.get(JobApplicationRow, application_id)
    if application is None:
        raise HTTPException(status_code=404, detail="지원 내역을 찾을 수 없습니다.")
    _assert_employer_company(payload, application.company_key or "")

    seeker = (
        db.query(QcMemberRow)
        .filter(QcMemberRow.email == (application.seeker_email or "").lower())
        .filter(QcMemberRow.member_type == "seeker")
        .first()
    )
    holdings = []
    if seeker is not None:
        try:
            profile = json.loads(seeker.seeker_profile_json or "{}")
        except json.JSONDecodeError:
            profile = {}
        holdings = profile.get("credentialHoldings") or []

    # 채용 확정 전에도 "보유 여부"는 알 수 있어야 하므로 imagePath 유무와
    # 무관하게 has_photo를 먼저 박아둔다(아래에서 imagePath 자체는 지워질 수 있음).
    holdings = [
        {**h, "has_photo": bool(h.get("imagePath"))}
        for h in holdings
        if isinstance(h, dict)
    ]

    can_view_documents = application.status in _ORIGINAL_DOCUMENT_VISIBLE_STATUSES
    if not can_view_documents:
        # 원본(사진 URL)은 채용 확정 단계 전에는 숨기고 보유 여부만 노출.
        holdings = [
            {k: v for k, v in h.items() if k != "imagePath"} for h in holdings
        ]

    return {
        "application_id": application_id,
        "seeker_email": application.seeker_email,
        "can_view_documents": can_view_documents,
        "held_credential_ids_at_apply": _held_ids_at_apply(application),
        "holdings": holdings,
    }


def _held_ids_at_apply(application: JobApplicationRow) -> list[str]:
    raw = application.held_credential_ids_json
    if not raw:
        return []
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return []
    return parsed if isinstance(parsed, list) else []
