"""어드민 — 외부 채용 사이트 URL 일괄 스크래핑 후 공고 등록."""

from __future__ import annotations

import json
import re
from uuid import uuid4

import httpx
from sqlalchemy.orm import Session

from app.config import settings
from app.services.admin_ops_service import bulk_import_jobs
from app.services.entitlement_service import normalize_brn
from app.services.job_post_scraper import ScrapeResult, fetch_job_post

_KAKAO_ADDRESS_URL = "https://dapi.kakao.com/v2/local/search/address.json"
_MAX_URLS = 30


def extract_urls(raw: str) -> list[str]:
    found: list[str] = []
    seen: set[str] = set()
    for token in re.split(r"[\s,]+", raw or ""):
        url = token.strip().strip("\"'")
        if not url.startswith(("http://", "https://")):
            continue
        if url in seen:
            continue
        seen.add(url)
        found.append(url)
        if len(found) >= _MAX_URLS:
            break
    return found


async def _geocode(query: str) -> tuple[float, float] | None:
    keyword = (query or "").strip()
    if not keyword or not settings.kakao_rest_api_key:
        return None
    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.get(
                _KAKAO_ADDRESS_URL,
                params={"query": keyword},
                headers={"Authorization": f"KakaoAK {settings.kakao_rest_api_key}"},
            )
            if response.status_code >= 400:
                return None
            documents = response.json().get("documents") or []
            if not documents:
                return None
            doc = documents[0]
            return float(doc["y"]), float(doc["x"])
    except (httpx.HTTPError, KeyError, TypeError, ValueError):
        return None


def _placeholder_title(url: str) -> str:
    return "알바몬 공고 (내용 확인 필요)"


def _scrape_to_job_dict(
    scraped: ScrapeResult,
    *,
    url: str,
    company_key: str,
    company_name: str,
    posted_by_email: str,
    posted_by_name: str,
    activate_job_pin: bool,
    latitude: float | None,
    longitude: float | None,
) -> dict:
    title = (scraped.title or "").strip() or _placeholder_title(url)
    warehouse = (scraped.workplace or "").strip() or "주소 확인 필요"
    wage = (scraped.hourly_wage or "").strip()
    schedule = (scraped.work_schedule or "").strip()
    description = (scraped.job_description or "").strip()
    if not description and scraped.description_images:
        description = "이미지 공고"
    if not description and scraped.raw_text:
        description = scraped.raw_text[:800].strip()
    if not description:
        description = f"출처: {url}\n(상세 내용은 나중에 수정해 주세요.)"

    description_body_json = "{}"
    if scraped.description_html or scraped.description_images:
        description_body_json = json.dumps(
            {
                **({"html": scraped.description_html} if scraped.description_html else {}),
                **(
                    {"images": scraped.description_images}
                    if scraped.description_images
                    else {}
                ),
            },
            ensure_ascii=False,
        )

    summary = title
    if scraped.error:
        summary = f"{title} · 스크래핑 일부 실패"

    post: dict = {
        "id": f"import_{uuid4().hex[:12]}",
        "title": title[:200],
        "company_name": company_name,
        "company_key": company_key,
        "warehouse_name": warehouse[:200],
        "hourly_wage": wage[:64],
        "work_schedule": schedule[:128],
        "summary": summary[:500],
        "job_description": description[:4000],
        "description_body_json": description_body_json,
        "status": "recruiting",
        "posted_by_email": posted_by_email,
        "posted_by_name": posted_by_name,
        "source_url": url,
        "scrape_confidence": scraped.confidence,
    }
    if latitude is not None and longitude is not None:
        post["workplace_latitude"] = latitude
        post["workplace_longitude"] = longitude
    if activate_job_pin:
        post["entitlements"] = {
            "recruitment_pin_active": True,
            "map_pin_tier": "packageActive",
        }
    return post


async def bulk_import_job_urls(
    db: Session,
    *,
    urls: list[str],
    company_key: str,
    company_name: str = "",
    posted_by_email: str = "",
    posted_by_name: str = "",
    activate_job_pin: bool = True,
) -> dict:
    brn = normalize_brn(company_key)
    if not brn:
        raise ValueError("company_key가 필요합니다.")

    results: list[dict] = []
    posts: list[dict] = []

    for url in urls:
        scraped = await fetch_job_post(url)
        warehouse = (scraped.workplace or "").strip() or "주소 확인 필요"
        coord = await _geocode(warehouse) if warehouse != "주소 확인 필요" else None
        lat, lng = coord if coord else (None, None)

        job = _scrape_to_job_dict(
            scraped,
            url=url,
            company_key=brn,
            company_name=company_name or "아라컴퍼니",
            posted_by_email=posted_by_email.strip().lower(),
            posted_by_name=posted_by_name,
            activate_job_pin=activate_job_pin,
            latitude=lat,
            longitude=lng,
        )
        posts.append(job)

        ok = not scraped.error or bool(
            scraped.title or scraped.raw_text or scraped.description_images
        )
        results.append(
            {
                "url": url,
                "post_id": job["id"],
                "title": job["title"],
                "ok": ok,
                "error": scraped.error,
                "confidence": scraped.confidence,
                "geocoded": lat is not None,
                "image_count": len(scraped.description_images),
            }
        )

    import_summary = bulk_import_jobs(db, posts) if posts else {
        "submitted": 0,
        "imported": 0,
        "updated": 0,
    }

    return {
        **import_summary,
        "urls_submitted": len(urls),
        "results": results,
    }
