from fastapi import Header, HTTPException

from app.config import settings


def require_admin_api_key(x_admin_api_key: str | None = Header(default=None)) -> str:
    expected = settings.admin_api_key.strip()
    if not expected:
        raise HTTPException(
            status_code=503,
            detail="ADMIN_API_KEY가 서버에 설정되지 않았습니다.",
        )
    if not x_admin_api_key or x_admin_api_key.strip() != expected:
        raise HTTPException(status_code=401, detail="Admin API key가 올바르지 않습니다.")
    return x_admin_api_key.strip()
