"""알바몬 상세 — BFF `/v1/recruit/view` · `/detail` (셸 HTML이 아닌 모집요강 content)."""

from __future__ import annotations

import logging
import re
from typing import Any
from urllib.parse import parse_qs, urlparse

import httpx
from bs4 import BeautifulSoup

logger = logging.getLogger(__name__)

_BFF_GENERAL = "https://bff-general.albamon.com"
_USER_AGENT = (
    "Mozilla/5.0 (compatible; IljariJobImporter/1.0; +https://iljari.co.kr/bot)"
)

_RECRUIT_NO_PATTERNS = (
    re.compile(r"/jobs/detail/(?:content/)?(\d{6,})", re.I),
    re.compile(r"[?&](?:recruitNo|giNo|gino)=(\d{6,})", re.I),
    re.compile(r"/recruit/view/(\d{6,})", re.I),
)

# 본문 content 안에도 섞이는 기업·공고 로고 영역
_CONTENT_LOGO_SELECTORS = (
    ".bLogo",
    ".blogo",
    ".companyLogo",
    ".company_logo",
    ".corpLogo",
    "[class*='bLogo']",
    "[class*='companyLogo']",
    "[class*='corp-logo']",
    "[class*='CorpLogo']",
)


def extract_albamon_recruit_no(url: str) -> str | None:
    trimmed = (url or "").strip()
    if not trimmed:
        return None
    for pattern in _RECRUIT_NO_PATTERNS:
        match = pattern.search(trimmed)
        if match:
            return match.group(1)
    path = urlparse(trimmed).path.rstrip("/")
    tail = path.split("/")[-1]
    if tail.isdigit() and len(tail) >= 6:
        return tail
    return None


async def fetch_albamon_bff_detail(
    recruit_no: str,
    *,
    client: httpx.AsyncClient | None = None,
    page_url: str = "",
) -> dict[str, Any]:
    """view 메타 + detail.content HTML. 실패 시 error 키."""
    owns = client is None
    if owns:
        client = httpx.AsyncClient(
            timeout=25,
            follow_redirects=True,
            headers={
                "User-Agent": _USER_AGENT,
                "Accept": "application/json",
                "Accept-Language": "ko-KR,ko;q=0.9",
                "Origin": "https://www.albamon.com",
                "Referer": page_url
                or f"https://www.albamon.com/jobs/detail/{recruit_no}",
                "Content-Type": "application/json",
            },
        )
    assert client is not None
    payload = {"recruitNo": int(recruit_no) if recruit_no.isdigit() else recruit_no}
    try:
        view_resp = await client.post(
            f"{_BFF_GENERAL}/v1/recruit/view",
            json=payload,
        )
        view_resp.raise_for_status()
        view = view_resp.json()
        detail_resp = await client.post(
            f"{_BFF_GENERAL}/v1/recruit/view/detail",
            json=payload,
        )
        detail_resp.raise_for_status()
        detail = detail_resp.json()
    except httpx.HTTPError as exc:
        logger.warning("albamon bff fetch failed recruitNo=%s: %s", recruit_no, exc)
        return {"error": str(exc), "recruit_no": recruit_no}
    finally:
        if owns:
            await client.aclose()

    content_html = (detail.get("content") or "") if isinstance(detail, dict) else ""
    cleaned_html, body_images = extract_body_images_from_content_html(content_html)
    return {
        "recruit_no": recruit_no,
        "view": view if isinstance(view, dict) else {},
        "content_html": cleaned_html,
        "raw_content_html": content_html,
        "body_images": body_images,
        "company_logo": _pick_company_logo(view if isinstance(view, dict) else {}),
    }


def extract_body_images_from_content_html(content_html: str) -> tuple[str, list[str]]:
    """모집요강 HTML에서 기업 로고 블록을 제거하고 본문 이미지만 추출."""
    if not (content_html or "").strip():
        return "", []

    soup = BeautifulSoup(content_html, "lxml")
    for selector in _CONTENT_LOGO_SELECTORS:
        for node in soup.select(selector):
            node.decompose()

    # 남은 img — 로고성 URL 제외
    images: list[str] = []
    seen: set[str] = set()
    for img in soup.find_all("img"):
        src = img.get("src") or img.get("data-src")
        if not isinstance(src, str) or not src.strip():
            continue
        absolute = src.strip()
        if absolute.startswith("//"):
            absolute = "https:" + absolute
        if absolute in seen:
            continue
        if _is_logoish_url(absolute, img):
            img.decompose()
            continue
        seen.add(absolute)
        images.append(absolute)

    # cleaned html: logo 제거된 상태. 이미지가 있으면 우리 표준 html로 재구성은 호출측에서.
    cleaned = str(soup.body.decode_contents()) if soup.body else str(soup)
    return cleaned.strip(), images


def _is_logoish_url(url: str, img) -> bool:
    lower = url.lower()
    if any(
        token in lower
        for token in (
            "logo",
            "wordmark",
            ".svg",
            "jk_co_",
            "mon_co_",
            "/corp/",
            "company-logo",
            "ci_logo",
            "c-photo-view",
            "/monimg/",
            "recruit/template",
            "top-image/view",
        )
    ):
        return True
    alt = (img.get("alt") or "").lower()
    if any(k in alt for k in ("로고", "logo", "기업로고", "company logo")):
        return True
    cls = " ".join(img.get("class") or []).lower() if img.get("class") else ""
    if "logo" in cls:
        return True
    return False


def _pick_company_logo(view: dict) -> str:
    for key in ("companyLogo", "company_logo", "logoUrl", "logo"):
        value = view.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    return ""


def fields_from_albamon_view(view: dict) -> dict[str, Any]:
    """BFF view JSON → scraper enrichment fields."""
    title = (
        view.get("recruitTitle")
        or view.get("title")
        or view.get("giTitle")
        or ""
    )
    company = view.get("recruitCompanyName") or view.get("companyName") or ""
    workplace = (
        view.get("workAddress")
        or view.get("address")
        or view.get("workPlace")
        or ""
    )
    if isinstance(workplace, dict):
        workplace = workplace.get("fullAddress") or workplace.get("address") or ""

    wage = ""
    pay = view.get("pay") or view.get("salary") or view.get("payText")
    if isinstance(pay, dict):
        wage = str(pay.get("text") or pay.get("value") or "").strip()
    elif isinstance(pay, str):
        wage = pay.strip()

    schedule = ""
    for key in ("workTime", "workSchedule", "workPeriodText", "workDays"):
        value = view.get(key)
        if isinstance(value, str) and value.strip():
            schedule = value.strip()
            break
        if isinstance(value, dict):
            text = value.get("text") or value.get("value")
            if text:
                schedule = str(text).strip()
                break

    return {
        "title": str(title).strip()[:200],
        "company_name": str(company).strip()[:200],
        "workplace": str(workplace).strip()[:200] if workplace else "",
        "hourly_wage": wage[:64],
        "work_schedule": schedule[:128],
        "company_logo": _pick_company_logo(view),
    }
