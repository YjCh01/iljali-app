"""외부 채용 사이트 HTML 수집·파싱 (서버 사이드 — CORS 회피)."""

from __future__ import annotations

import re
import time
from dataclasses import dataclass, field
from html import unescape
from typing import Optional
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup

from app.config import settings
from app.services.job_post_image_extractor import (
    extract_image_job_body,
    should_try_image_extract,
)

_USER_AGENT = (
    "Mozilla/5.0 (compatible; IljariJobImporter/1.0; +https://iljari.co.kr/bot)"
)
_last_fetch_at: float = 0.0


@dataclass
class ScrapeResult:
    platform: str
    raw_text: str
    title: str = ""
    hourly_wage: str | None = None
    work_schedule: str = ""
    workplace: str | None = None
    job_description: str = ""
    description_html: str = ""
    description_images: list[str] = field(default_factory=list)
    confidence: float = 0.5
    source_url: str = ""
    error: str | None = None


def detect_platform(url: str) -> str:
    lower = url.lower()
    if "albamon" in lower:
        return "albamon"
    if "saramin" in lower:
        return "saramin"
    if "albacheon" in lower or "alba.co.kr" in lower or "albaheaven" in lower:
        return "albacheon"
    if "incruit" in lower:
        return "incruit"
    if "dongnealba" in lower:
        return "dongnealba"
    if "karrot" in lower or "daangn" in lower:
        return "karrot"
    return "unknown"


def _rate_limit_wait() -> None:
    global _last_fetch_at
    min_interval = max(0.5, settings.job_scrape_min_interval_sec)
    elapsed = time.monotonic() - _last_fetch_at
    if elapsed < min_interval:
        time.sleep(min_interval - elapsed)
    _last_fetch_at = time.monotonic()


def _meta_content(soup: BeautifulSoup, prop: str) -> str:
    tag = soup.find("meta", property=prop) or soup.find("meta", attrs={"name": prop})
    if tag and tag.get("content"):
        return unescape(str(tag["content"]).strip())
    return ""


def _visible_text(soup: BeautifulSoup) -> str:
    for tag in soup(["script", "style", "noscript", "svg", "iframe"]):
        tag.decompose()
    text = soup.get_text("\n", strip=True)
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    return "\n".join(lines)


def _parse_structured_fields(text: str) -> dict:
    title = ""
    bracket = re.search(r"[「\[]([^」\]]{2,60})[」\]]", text)
    if bracket:
        title = bracket.group(1).strip()
    else:
        for line in text.splitlines():
            line = line.strip()
            if 4 <= len(line) <= 80 and (
                "모집" in line or "채용" in line or "알바" in line or "구인" in line
            ):
                title = line
                break

    wage = None
    hourly = re.search(r"시급\s*[:：]?\s*([0-9,]{4,7})\s*원?", text, re.I)
    if hourly:
        wage = f"시급 {hourly.group(1).replace(',', '')}"
    else:
        daily = re.search(r"일급\s*[:：]?\s*([0-9,]{4,8})\s*원?", text, re.I)
        if daily:
            wage = f"일급 {daily.group(1).replace(',', '')}"

    schedule = ""
    time_match = re.search(
        r"(\d{1,2}\s*:\s*\d{2})\s*[~\-–]\s*(\d{1,2}\s*:\s*\d{2})",
        text,
    )
    if time_match:
        schedule = (
            f"{time_match.group(1).replace(' ', '')}"
            f"-{time_match.group(2).replace(' ', '')}"
        )

    workplace = None
    addr = re.search(
        r"((?:서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)"
        r"[^\n]{4,80})",
        text,
    )
    if addr:
        workplace = addr.group(1).strip()[:120]

    desc_lines: list[str] = []
    for line in text.splitlines():
        ln = line.strip()
        if len(ln) < 8:
            continue
        if any(k in ln for k in ("시급", "일급", "근무", "주소", "모집", "연락")):
            continue
        desc_lines.append(ln)
        if len(desc_lines) >= 6:
            break

    confidence = 0.4
    if title:
        confidence += 0.2
    if wage:
        confidence += 0.15
    if schedule:
        confidence += 0.1
    if workplace:
        confidence += 0.1

    return {
        "title": title,
        "hourly_wage": wage,
        "work_schedule": schedule,
        "workplace": workplace,
        "job_description": "\n".join(desc_lines)[:500],
        "confidence": min(confidence, 0.95),
    }


def _site_enrich(platform: str, soup: BeautifulSoup, text: str) -> dict:
    extra: dict = {}
    if platform == "albamon":
        title_el = soup.select_one(".title, .job_title, h1, .tit_job")
        if title_el:
            extra["title"] = title_el.get_text(strip=True)
        wage_el = soup.select_one(".pay, .salary, .money")
        if wage_el:
            wage_txt = wage_el.get_text(" ", strip=True)
            m = re.search(r"([0-9,]{4,7})", wage_txt)
            if m:
                extra["hourly_wage"] = f"시급 {m.group(1).replace(',', '')}"
    elif platform == "saramin":
        title_el = soup.select_one("h1, .job_tit, .tit_job")
        if title_el:
            extra["title"] = title_el.get_text(strip=True)
    elif platform in ("albacheon", "incruit"):
        title_el = soup.select_one("h1, .title, .job_title")
        if title_el:
            extra["title"] = title_el.get_text(strip=True)

    og_title = _meta_content(soup, "og:title")
    og_desc = _meta_content(soup, "og:description")
    if not extra.get("title") and og_title:
        extra["title"] = og_title
    if og_desc and not extra.get("job_description"):
        extra["job_description"] = og_desc[:500]

    parsed = _parse_structured_fields(text)
    for key, value in extra.items():
        if value:
            parsed[key] = value
    return parsed


async def fetch_job_post(url: str, *, platform: str | None = None) -> ScrapeResult:
    """URL에서 HTML을 가져와 공고 텍스트·필드를 추출합니다."""
    trimmed = url.strip()
    if not trimmed.startswith(("http://", "https://")):
        return ScrapeResult(
            platform=platform or "unknown",
            raw_text="",
            source_url=trimmed,
            error="http 또는 https URL이 필요합니다.",
        )

    host = urlparse(trimmed).netloc.lower()
    blocked_hosts = {h.strip().lower() for h in settings.job_scrape_blocklist.split(",") if h.strip()}
    if host in blocked_hosts:
        return ScrapeResult(
            platform=platform or detect_platform(trimmed),
            raw_text="",
            source_url=trimmed,
            error="차단된 호스트입니다.",
        )

    detected = platform or detect_platform(trimmed)
    _rate_limit_wait()

    try:
        async with httpx.AsyncClient(
            timeout=settings.job_scrape_timeout_sec,
            follow_redirects=True,
            headers={"User-Agent": _USER_AGENT, "Accept-Language": "ko-KR,ko;q=0.9"},
        ) as client:
            response = await client.get(trimmed)
            response.raise_for_status()
            html = response.text
    except httpx.HTTPError as exc:
        return ScrapeResult(
            platform=detected,
            raw_text="",
            source_url=trimmed,
            error=f"페이지를 가져오지 못했습니다: {exc}",
        )

    soup = BeautifulSoup(html, "lxml")
    raw_text = _visible_text(soup)
    if len(raw_text) < 40:
        raw_text = f"{_meta_content(soup, 'og:title')}\n{_meta_content(soup, 'og:description')}"

    fields = _site_enrich(detected, soup, raw_text)

    job_description = (fields.get("job_description") or "").strip()
    description_html = ""
    description_images: list[str] = []
    if should_try_image_extract(job_description, platform=detected):
        description_html, description_images = extract_image_job_body(
            soup,
            trimmed,
            platform=detected,
        )
        if description_images and not job_description:
            job_description = "이미지 공고"
            fields["confidence"] = min(
                float(fields.get("confidence", 0.5)) + 0.25,
                0.95,
            )

    return ScrapeResult(
        platform=detected,
        raw_text=raw_text[:8000],
        title=fields.get("title", ""),
        hourly_wage=fields.get("hourly_wage"),
        work_schedule=fields.get("work_schedule", ""),
        workplace=fields.get("workplace"),
        job_description=job_description,
        description_html=description_html,
        description_images=description_images,
        confidence=float(fields.get("confidence", 0.5)),
        source_url=trimmed,
    )
