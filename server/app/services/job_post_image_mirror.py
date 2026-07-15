"""외부 공고 본문 이미지를 우리 `/media/job-posts`로 미러링."""

from __future__ import annotations

import logging
from pathlib import Path
from urllib.parse import urlparse
from uuid import uuid4

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

_USER_AGENT = (
    "Mozilla/5.0 (compatible; IljariJobImporter/1.0; +https://iljari.co.kr/bot)"
)

_EXT_BY_CONTENT_TYPE = {
    "image/jpeg": ".jpg",
    "image/jpg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/gif": ".gif",
}

_MAX_BYTES = 8 * 1024 * 1024
_ALLOW_HOST_SUFFIXES = (
    "albamon.com",
    "albamon.kr",
    "saraminimage.co.kr",
    "saramin.co.kr",
    "alba.co.kr",
    "incruit.com",
)


def ensure_job_media_dir() -> Path:
    media_dir = Path(settings.job_media_dir)
    media_dir.mkdir(parents=True, exist_ok=True)
    return media_dir


def is_our_job_media_url(url: str) -> bool:
    lower = (url or "").lower()
    return "/media/job-posts/" in lower


def is_external_job_cdn(url: str) -> bool:
    host = urlparse(url or "").netloc.lower()
    if not host:
        return False
    return any(host == s or host.endswith("." + s) for s in _ALLOW_HOST_SUFFIXES)


def _guess_ext(url: str, content_type: str | None) -> str:
    if content_type:
        mime = content_type.split(";")[0].strip().lower()
        if mime in _EXT_BY_CONTENT_TYPE:
            return _EXT_BY_CONTENT_TYPE[mime]
    path = urlparse(url).path.lower()
    for ext in (".jpg", ".jpeg", ".png", ".webp", ".gif"):
        if path.endswith(ext):
            return ".jpg" if ext == ".jpeg" else ext
    return ".jpg"


async def mirror_image_urls(
    urls: list[str],
    *,
    referer: str,
    client: httpx.AsyncClient | None = None,
) -> list[str]:
    """외부 이미지 URL → 공개 `/media/job-posts/...` URL. 실패 시 원본 유지."""
    if not urls:
        return []

    owns_client = client is None
    if owns_client:
        client = httpx.AsyncClient(
            timeout=settings.job_scrape_timeout_sec,
            follow_redirects=True,
            headers={"User-Agent": _USER_AGENT, "Accept-Language": "ko-KR,ko;q=0.9"},
        )

    assert client is not None
    media_dir = ensure_job_media_dir()
    base = settings.api_public_base_url.rstrip("/")
    out: list[str] = []

    try:
        for url in urls:
            if is_our_job_media_url(url):
                out.append(url)
                continue
            if not url.startswith(("http://", "https://")):
                out.append(url)
                continue
            mirrored = await _download_one(
                client,
                url,
                referer=referer,
                media_dir=media_dir,
                public_base=base,
            )
            out.append(mirrored or url)
    finally:
        if owns_client:
            await client.aclose()

    return out


async def _download_one(
    client: httpx.AsyncClient,
    url: str,
    *,
    referer: str,
    media_dir: Path,
    public_base: str,
) -> str | None:
    try:
        response = await client.get(
            url,
            headers={
                "Referer": referer or url,
                "Accept": "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
            },
        )
        response.raise_for_status()
    except httpx.HTTPError as exc:
        logger.warning("job image mirror fetch failed: %s (%s)", url[:120], exc)
        return None

    content_type = (response.headers.get("content-type") or "").lower()
    body = response.content
    if len(body) < 32 or len(body) > _MAX_BYTES:
        logger.warning("job image mirror skip size=%s url=%s", len(body), url[:120])
        return None
    if content_type and not content_type.startswith("image/") and "octet-stream" not in content_type:
        # some CDNs omit/generic type — still accept if magic looks like image
        if not _looks_like_image(body):
            logger.warning("job image mirror non-image type=%s url=%s", content_type, url[:120])
            return None

    ext = _guess_ext(url, content_type)
    name = f"{uuid4().hex}{ext}"
    dest = media_dir / name
    dest.write_bytes(body)
    return f"{public_base}/media/job-posts/{name}"


def _looks_like_image(data: bytes) -> bool:
    if data.startswith(b"\xff\xd8\xff"):
        return True  # jpeg
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return True
    if data[:6] in (b"GIF87a", b"GIF89a"):
        return True
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return True
    return False
