"""공고 본문 이미지 재미러 — 알바몬은 BFF 재수집, 로고 오탐은 제거."""

from __future__ import annotations

import json
import logging
import re
import struct
from pathlib import Path
from urllib.parse import urlparse

import httpx
from sqlalchemy.orm import Session

from app.config import settings
from app.job_sync_models import JobPostRow
from app.services.albamon_bff_scraper import (
    extract_albamon_recruit_no,
    fetch_albamon_bff_detail,
)
from app.services.job_post_image_extractor import images_to_html
from app.services.job_post_image_mirror import (
    is_external_job_cdn,
    is_our_job_media_url,
    mirror_image_urls,
)

logger = logging.getLogger(__name__)

_IMG_SRC_RE = re.compile(
    r"""<img[^>]+src=["']([^"']+)["']""",
    re.IGNORECASE,
)


def _extract_urls_from_body(body: dict) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()
    for url in body.get("images") or []:
        if isinstance(url, str) and url.strip() and url not in seen:
            seen.add(url)
            ordered.append(url.strip())
    html = body.get("html") or ""
    if isinstance(html, str):
        for match in _IMG_SRC_RE.findall(html):
            if match not in seen:
                seen.add(match)
                ordered.append(match)
    return ordered


def _read_image_dims(data: bytes) -> tuple[int | None, int | None]:
    if data.startswith(b"\x89PNG") and len(data) >= 24:
        w, h = struct.unpack(">II", data[16:24])
        return int(w), int(h)
    if data[:6] in (b"GIF87a", b"GIF89a") and len(data) >= 10:
        w, h = struct.unpack("<HH", data[6:10])
        return int(w), int(h)
    if data[:2] == b"\xff\xd8":
        i = 2
        while i < len(data) - 8:
            if data[i] != 0xFF:
                i += 1
                continue
            marker = data[i + 1]
            if marker in (0xC0, 0xC1, 0xC2):
                h, w = struct.unpack(">HH", data[i + 5 : i + 9])
                return int(w), int(h)
            if marker == 0xD9:
                break
            if marker in (0xD8, 0x01) or 0xD0 <= marker <= 0xD7:
                i += 2
                continue
            ln = struct.unpack(">H", data[i + 2 : i + 4])[0]
            i += 2 + ln
    return None, None


def _looks_like_logo_bytes(data: bytes) -> bool:
    """작은·가로배너·저용량 희소 PNG 등은 기업 로고로 간주."""
    if len(data) < 800:
        return True
    w, h = _read_image_dims(data)
    if w is None or h is None:
        return len(data) < 12_000
    area = w * h
    if area < 80_000:
        return True
    if h < 140:
        return True
    if h < 280 and w / max(h, 1) >= 2.2:
        return True
    # 큰 캔버스지만 파일 작은 단색/로고 PNG
    if len(data) < 25_000 and area >= 100_000:
        return True
    if len(data) < 12_000:
        return True
    return False


_PLACEHOLDER_DESC = {
    "",
    "이미지 공고",
    "클릭하여 상세내용을 확인하세요",
}


def _is_placeholder_logo_import(row: JobPostRow, body: dict) -> bool:
    """기존 잘못된 알바몬 셸 스크래핑(로고만) 패턴."""
    desc = (row.job_description or "").strip()
    if desc == "클릭하여 상세내용을 확인하세요":
        return True
    if body.get("source_url"):
        return False
    imgs = body.get("images") or []
    if not imgs:
        return False
    # source_url 없이 media 이미지만 있고 placeholder 본문 → 로고 오탐으로 간주
    if desc in _PLACEHOLDER_DESC and all(
        isinstance(u, str) and "/media/job-posts/" in u for u in imgs
    ):
        return True
    return False


def _local_media_path(url: str) -> Path | None:
    if "/media/job-posts/" not in url:
        return None
    name = urlparse(url).path.split("/media/job-posts/")[-1]
    if not name or "/" in name or ".." in name:
        return None
    return Path(settings.job_media_dir) / name


async def remirror_job_post_images(
    db: Session,
    *,
    post_id: str | None = None,
    limit: int = 50,
    rescrape: bool = True,
) -> dict:
    """
    - source_url(알바몬)이 있으면 BFF 모집요강으로 본문 이미지를 다시 수집
    - 없으면 기존 URL 재미러하되, 로고로 보이는 이미지는 제거
    """
    if post_id:
        rows = [db.get(JobPostRow, post_id)]
        if rows[0] is None:
            return {"ok": False, "error": "공고를 찾을 수 없습니다.", "results": []}
    else:
        rows = (
            db.query(JobPostRow)
            .order_by(JobPostRow.created_at.desc())
            .limit(max(1, min(limit, 200)))
            .all()
        )

    results: list[dict] = []
    updated = 0
    for row in rows:
        if row is None:
            continue
        try:
            body = json.loads(row.description_body_json or "{}")
            if not isinstance(body, dict):
                body = {}
        except json.JSONDecodeError:
            body = {}

        source_url = (body.get("source_url") or "").strip()
        if not source_url:
            # job_description 출처 라인 호환
            desc = row.job_description or ""
            m = re.search(r"https?://\S*albamon\S*", desc)
            if m:
                source_url = m.group(0).rstrip(").,]")

        if rescrape and source_url and "albamon" in source_url.lower():
            result = await _rescrape_albamon(row, body, source_url)
            results.append(result)
            if result.get("changed"):
                updated += 1
            continue

        # 로고만 끌어온 옛 import → 본문 이미지 전부 제거 (재등록 유도)
        if _is_placeholder_logo_import(row, body):
            body.pop("images", None)
            body.pop("html", None)
            row.description_body_json = json.dumps(
                {k: v for k, v in body.items() if k == "source_url"} or {},
                ensure_ascii=False,
            )
            updated += 1
            results.append(
                {
                    "id": row.id,
                    "ok": True,
                    "changed": True,
                    "image_count": 0,
                    "action": "clear_logo_placeholder_import",
                }
            )
            continue

        urls = _extract_urls_from_body(body)
        if not urls and post_id is None:
            continue
        if not urls:
            results.append(
                {
                    "id": row.id,
                    "ok": False,
                    "skipped": True,
                    "reason": "images empty",
                }
            )
            continue

        # 로고 오탐 제거 (로컬 media 바이트 기반)
        kept: list[str] = []
        dropped = 0
        for url in urls:
            local = _local_media_path(url)
            data: bytes | None = None
            if local and local.is_file():
                data = local.read_bytes()
            elif is_external_job_cdn(url):
                try:
                    async with httpx.AsyncClient(timeout=20, follow_redirects=True) as client:
                        resp = await client.get(
                            url,
                            headers={"Referer": "https://www.albamon.com/"},
                        )
                        if resp.status_code == 200:
                            data = resp.content
                except httpx.HTTPError:
                    data = None
            if data is not None and _looks_like_logo_bytes(data):
                dropped += 1
                continue
            kept.append(url)

        if kept != urls:
            if kept:
                # 남은 외부 URL만 재미러
                external = [u for u in kept if is_external_job_cdn(u)]
                if external:
                    mirrored_map = dict(
                        zip(
                            external,
                            await mirror_image_urls(
                                external, referer="https://www.albamon.com/"
                            ),
                        )
                    )
                    kept = [mirrored_map.get(u, u) for u in kept]
                body["images"] = kept
                body["html"] = images_to_html(kept)
            else:
                body.pop("images", None)
                body.pop("html", None)
                if not body.get("text"):
                    body = {k: v for k, v in body.items() if k == "source_url"}
            row.description_body_json = json.dumps(body, ensure_ascii=False)
            updated += 1
            results.append(
                {
                    "id": row.id,
                    "ok": True,
                    "changed": True,
                    "dropped_logos": dropped,
                    "image_count": len(kept),
                    "action": "filter_logos",
                }
            )
        else:
            results.append(
                {
                    "id": row.id,
                    "ok": True,
                    "changed": False,
                    "image_count": len(urls),
                    "action": "unchanged",
                }
            )

    db.commit()
    return {"ok": True, "updated": updated, "results": results}


async def _rescrape_albamon(row: JobPostRow, body: dict, source_url: str) -> dict:
    recruit_no = extract_albamon_recruit_no(source_url)
    if not recruit_no:
        return {
            "id": row.id,
            "ok": False,
            "reason": "recruitNo missing",
            "source_url": source_url,
        }
    detail = await fetch_albamon_bff_detail(recruit_no, page_url=source_url)
    if detail.get("error"):
        return {
            "id": row.id,
            "ok": False,
            "reason": detail["error"],
            "source_url": source_url,
        }
    images = list(detail.get("body_images") or [])
    company_logo = (detail.get("company_logo") or "").strip()
    if company_logo:
        images = [u for u in images if u != company_logo]
    if images:
        images = await mirror_image_urls(images, referer=source_url)
        body["images"] = images
        body["html"] = images_to_html(images)
    else:
        body.pop("images", None)
        content = (detail.get("content_html") or "").strip()
        if content:
            body["html"] = content
        else:
            body.pop("html", None)
    body["source_url"] = source_url
    row.description_body_json = json.dumps(body, ensure_ascii=False)
    if images and (row.job_description or "").strip() in (
        "",
        "이미지 공고",
        "클릭하여 상세내용을 확인하세요",
    ):
        row.job_description = "이미지 공고"
    return {
        "id": row.id,
        "ok": True,
        "changed": True,
        "image_count": len(images),
        "action": "rescrape_bff",
        "recruit_no": recruit_no,
    }
