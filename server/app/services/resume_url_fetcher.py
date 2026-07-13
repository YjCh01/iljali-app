"""알바몬·잡코리아 등 이력서 URL → 텍스트 (로그인 필요 시 안내)."""

from __future__ import annotations

import re

import httpx
from bs4 import BeautifulSoup

_LOGIN_HINTS = (
    "로그인",
    "login",
    "sign in",
    "회원가입",
    "본인인증",
    "access denied",
)


def detect_resume_platform(url: str) -> str:
    lower = (url or "").lower()
    if "albamon" in lower:
        return "albamon"
    if "jobkorea" in lower or "jobkorea.co.kr" in lower:
        return "jobkorea"
    if "saramin" in lower:
        return "saramin"
    if "incruit" in lower:
        return "incruit"
    return "unknown"


async def fetch_resume_url_text(url: str) -> tuple[str, str, str | None]:
    target = (url or "").strip()
    if not target.startswith(("http://", "https://")):
        raise ValueError("http:// 또는 https:// 로 시작하는 링크를 입력해 주세요.")

    platform = detect_resume_platform(target)
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
        ),
        "Accept-Language": "ko-KR,ko;q=0.9",
    }

    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True, headers=headers) as client:
        response = await client.get(target)

    if response.status_code >= 400:
        return "", platform, f"페이지를 열 수 없습니다 (HTTP {response.status_code})."

    html = response.text or ""
    lower_html = html.lower()
    if any(hint in lower_html for hint in _LOGIN_HINTS) and len(html) < 12000:
        return (
            "",
            platform,
            "로그인이 필요한 페이지로 보입니다. "
            "이력서 화면을 캡처하거나 PDF로 저장해 업로드해 주세요.",
        )

    soup = BeautifulSoup(html, "lxml")
    for tag in soup(["script", "style", "noscript", "svg"]):
        tag.decompose()

    text = re.sub(r"\n{3,}", "\n\n", soup.get_text("\n", strip=True))
    text = text.strip()
    if len(text) < 80:
        return (
            "",
            platform,
            "페이지에서 이력서 내용을 충분히 읽지 못했습니다. "
            "캡처·PDF 업로드를 권장합니다.",
        )
    return text[:20000], platform, None
