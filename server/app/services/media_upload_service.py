"""공용 이미지 업로드 검증·저장 — 공고/자격증/사업자등록증 등에서 재사용."""

from pathlib import Path
from uuid import uuid4

from fastapi import HTTPException, UploadFile

from app.config import settings

ALLOWED_IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
MAX_UPLOAD_BYTES = 8 * 1024 * 1024


def ensure_media_dir(dir_path: str) -> Path:
    media_dir = Path(dir_path)
    media_dir.mkdir(parents=True, exist_ok=True)
    return media_dir


async def save_uploaded_image(
    file: UploadFile,
    *,
    dir_path: str,
    url_prefix: str,
) -> dict:
    """이미지 업로드 검증(크기·확장자) 후 저장 — {"url", "filename"} 반환."""
    content = await file.read()
    if len(content) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=413, detail="파일 크기는 8MB 이하여야 합니다.")
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_IMAGE_EXTENSIONS:
        raise HTTPException(
            status_code=400, detail="jpg, png, webp, gif만 업로드할 수 있습니다."
        )

    media_dir = ensure_media_dir(dir_path)
    name = f"{uuid4().hex}{ext}"
    (media_dir / name).write_bytes(content)

    base = settings.api_public_base_url.rstrip("/")
    url = f"{base}{url_prefix}/{name}"
    return {"url": url, "filename": name}
