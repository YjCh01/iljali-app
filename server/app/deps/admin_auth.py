import sys

from fastapi import Header, HTTPException

from app.config import settings

# 저장소에 공개된 기본값 — 운영 환경에서 교체하지 않았다면 절대 통과시키지 않는다.
_KNOWN_DEV_DEFAULT = "qc-admin-dev-key"


def require_admin_api_key(x_admin_api_key: str | None = Header(default=None)) -> str:
    expected = settings.admin_api_key.strip()
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="ADMIN_API_KEY가 서버에 설정되지 않았습니다.",
        )
    if expected == _KNOWN_DEV_DEFAULT and "pytest" not in sys.modules:
        raise HTTPException(
            status_code=503,
            detail="ADMIN_API_KEY가 저장소 기본값입니다. 운영 환경에서는 반드시 교체해야 합니다.",
        )
    if not x_admin_api_key or x_admin_api_key.strip() != expected:
        raise HTTPException(status_code=401, detail="Admin API key가 올바르지 않습니다.")
    return x_admin_api_key.strip()
