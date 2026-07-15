"""공고 본문 — HTML 이미지형(알바몬 등) 추출."""

from __future__ import annotations

import re
from html import escape
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup, Tag

_SKIP_URL_TOKENS = (
    "logo",
    "icon",
    "btn_",
    "button",
    "spacer",
    "blank.gif",
    "noimg",
    "profile",
    "sns",
    "kakao",
    "share",
    "banner_ad",
    "ad_",
    "/ad/",
)

_PLATFORM_ROOT_SELECTORS: dict[str, list[str]] = {
    "albamon": [
        "#devGiDetail",
        ".gi_detail",
        ".detail_contents",
        ".detailCont",
        ".job_detail",
        ".view_contents",
        ".recruit_detail",
        "article.detail",
        ".detail-view",
        ".recruit-view",
        "#JobDetail",
        "[class*='detail']",
    ],
    "saramin": [".job_detail", ".wrap_jview", "article"],
    "albacheon": [".detail_view", ".view_area", "article"],
    "incruit": [".job_detail", ".view_cont", "article"],
}

_GENERIC_ROOT_SELECTORS = ["main", "article", "#content", ".content", ".detail"]


def should_try_image_extract(job_description: str, *, platform: str) -> bool:
    """이미지 본문 추출을 시도할지.

    알바몬은 og/사이드바 텍스트가 길어도 본문이 이미지인 경우가 많아
    항상 시도한다. 그 외 플랫폼은 텍스트가 짧을 때만.
    """
    if platform == "albamon":
        return True
    stripped = (job_description or "").strip()
    if len(stripped) >= 40:
        return False
    if stripped:
        return len(stripped) < 20
    return True


def extract_image_job_body(
    soup: BeautifulSoup,
    page_url: str,
    *,
    platform: str,
) -> tuple[str, list[str]]:
    """(html, image_urls) — 우리 description_body 형식."""
    roots = _collect_roots(soup, platform)
    images = _collect_image_urls(roots, page_url, platform=platform)
    if not images:
        return "", []

    html = images_to_html(images)
    return html, images


def images_to_html(image_urls: list[str]) -> str:
    parts: list[str] = []
    for url in image_urls:
        safe = escape(url, quote=True)
        parts.append(
            f'<p><img src="{safe}" alt="공고 이미지" '
            f'style="max-width:100%;height:auto;display:block;" /></p>'
        )
    return "".join(parts)


def _collect_roots(soup: BeautifulSoup, platform: str) -> list[Tag]:
    selectors = list(_PLATFORM_ROOT_SELECTORS.get(platform, []))
    selectors.extend(_GENERIC_ROOT_SELECTORS)
    roots: list[Tag] = []
    seen_ids: set[int] = set()
    for selector in selectors:
        for node in soup.select(selector):
            node_id = id(node)
            if node_id in seen_ids:
                continue
            seen_ids.add(node_id)
            roots.append(node)
    return roots or [soup.body or soup]


def _collect_image_urls(
    roots: list[Tag],
    page_url: str,
    *,
    platform: str,
) -> list[str]:
    ordered: list[str] = []
    seen: set[str] = set()

    for root in roots:
        for img in root.find_all("img"):
            for candidate in _img_src_candidates(img):
                absolute = _normalize_url(page_url, candidate)
                if not absolute or absolute in seen:
                    continue
                if _is_decorative(absolute, img):
                    continue
                if platform == "albamon":
                    if not _is_plausible_job_image(absolute, platform):
                        continue
                elif not re.search(r"\.(jpe?g|png|webp|gif)(\?|$)", absolute.lower()):
                    continue
                seen.add(absolute)
                ordered.append(absolute)

    if platform == "albamon":
        ordered.sort(key=_albamon_image_rank, reverse=True)
    return ordered[:24]


def _img_src_candidates(img: Tag) -> list[str]:
    values: list[str] = []
    for attr in ("src", "data-src", "data-original", "data-lazy", "data-lazy-src"):
        raw = img.get(attr)
        if isinstance(raw, str) and raw.strip():
            values.append(raw.strip())
    srcset = img.get("srcset")
    if isinstance(srcset, str):
        first = srcset.split(",")[0].strip().split(" ")[0].strip()
        if first:
            values.append(first)
    return values


def _normalize_url(page_url: str, raw: str) -> str:
    trimmed = raw.strip()
    if not trimmed or trimmed.startswith("data:"):
        return ""
    return urljoin(page_url, trimmed)


def _int_attr(value: object | None) -> int | None:
    if value is None:
        return None
    try:
        return int(str(value).replace("px", "").strip())
    except ValueError:
        return None


def _is_decorative(url: str, img: Tag) -> bool:
    lower = url.lower()
    if any(token in lower for token in _SKIP_URL_TOKENS):
        return True
    width = _int_attr(img.get("width"))
    height = _int_attr(img.get("height"))
    if width is not None and height is not None and (width < 48 or height < 48):
        return True
    return False


def _is_plausible_job_image(url: str, platform: str) -> bool:
    lower = url.lower()
    if platform == "albamon":
        host = urlparse(url).netloc.lower()
        # 확장자 없는 CDN (C-Photo-View?FN=…) 포함
        if "file.albamon.com" in host or host.endswith("albamon.com") or host.endswith(
            "albamon.kr"
        ):
            if any(skip in lower for skip in ("wordmark", "logo", ".svg", "icon")):
                return False
            return True
        return False
    host = urlparse(url).netloc.lower()
    return bool(host) and (
        re.search(r"\.(jpe?g|png|webp|gif)(\?|$)", lower) is not None
        or "photo-view" in lower
        or "c-photo" in lower
    )


def _albamon_image_rank(url: str) -> int:
    lower = url.lower()
    score = 0
    if "file.albamon.com" in lower:
        score += 100
    if any(
        k in lower
        for k in (
            "recruit",
            "giimg",
            "detail",
            "editor",
            "upload",
            "c-photo-view",
            "photo-view",
        )
    ):
        score += 40
    if re.search(r"\.(jpe?g|png|webp)$", lower.split("?")[0]):
        score += 10
    return score
