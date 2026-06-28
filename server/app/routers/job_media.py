"""공고 본문 이미지 업로드."""

from pathlib import Path
from uuid import uuid4

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.config import settings

router = APIRouter(prefix="/v1/job-media", tags=["job-media"])

_ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
_MAX_BYTES = 8 * 1024 * 1024


def ensure_job_media_dir() -> Path:
    media_dir = Path(settings.job_media_dir)
    media_dir.mkdir(parents=True, exist_ok=True)
    return media_dir


@router.post("/upload")
async def upload_job_media(file: UploadFile = File(...)):
    content = await file.read()
    if len(content) > _MAX_BYTES:
        raise HTTPException(
            status_code=413,
            detail="파일 크기는 8MB 이하여야 합니다.",
        )
    ext = Path(file.filename or "").suffix.lower()
    if ext not in _ALLOWED_EXT:
        raise HTTPException(
            status_code=400,
            detail="jpg, png, webp, gif만 업로드할 수 있습니다.",
        )

    media_dir = ensure_job_media_dir()
    name = f"{uuid4().hex}{ext}"
    dest = media_dir / name
    dest.write_bytes(content)

    base = settings.api_public_base_url.rstrip("/")
    url = f"{base}/media/job-posts/{name}"
    return {"url": url, "filename": name}
