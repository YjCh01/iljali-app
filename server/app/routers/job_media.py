"""공고 본문 이미지 업로드·프록시."""

from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4

import httpx
from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from fastapi.responses import Response

from app.config import settings
from app.services.job_post_image_mirror import (
    ensure_job_media_dir,
    is_external_job_cdn,
)

router = APIRouter(prefix="/v1/job-media", tags=["job-media"])

_ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
_MAX_BYTES = 8 * 1024 * 1024
_USER_AGENT = (
    "Mozilla/5.0 (compatible; IljariJobImporter/1.0; +https://iljari.co.kr/bot)"
)


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


@router.get("/proxy")
async def proxy_job_media(
    url: str = Query(..., min_length=8, max_length=2000),
    referer: str | None = Query(None, max_length=2000),
):
    """외부 채용 CDN 이미지를 우리 도메인으로 프록시 (핫링크 403 우회)."""
    if not url.startswith(("http://", "https://")):
        raise HTTPException(status_code=400, detail="http(s) URL만 허용됩니다.")
    if not is_external_job_cdn(url):
        raise HTTPException(status_code=400, detail="허용되지 않은 이미지 호스트입니다.")

    host = urlparse(url).netloc
    default_referer = f"https://{host}/" if host else "https://www.albamon.com/"
    try:
        async with httpx.AsyncClient(
            timeout=settings.job_scrape_timeout_sec,
            follow_redirects=True,
            headers={"User-Agent": _USER_AGENT, "Accept-Language": "ko-KR,ko;q=0.9"},
        ) as client:
            response = await client.get(
                url,
                headers={
                    "Referer": referer or default_referer,
                    "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
                },
            )
            response.raise_for_status()
    except httpx.HTTPError as exc:
        raise HTTPException(
            status_code=502,
            detail=f"이미지를 가져오지 못했습니다: {exc}",
        ) from exc

    content = response.content
    if len(content) > _MAX_BYTES:
        raise HTTPException(status_code=413, detail="이미지가 너무 큽니다.")
    content_type = response.headers.get("content-type") or "image/jpeg"
    if not content_type.startswith("image/") and "octet-stream" not in content_type:
        raise HTTPException(status_code=502, detail="이미지 응답이 아닙니다.")

    return Response(
        content=content,
        media_type=content_type.split(";")[0].strip(),
        headers={"Cache-Control": "public, max-age=86400"},
    )
