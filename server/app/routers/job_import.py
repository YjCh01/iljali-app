"""외부 채용 사이트 공고 가져오기 — 서버 사이드 스크래핑."""

from __future__ import annotations

import re
from typing import Optional

from fastapi import APIRouter
from pydantic import BaseModel

from app.services.job_post_scraper import detect_platform, fetch_job_post

router = APIRouter(prefix="/v1/job-import", tags=["job-import"])


def _description_body_payload(
    *,
    description_html: str,
    description_images: list[str],
) -> dict:
    body: dict = {}
    if description_html.strip():
        body["html"] = description_html.strip()
    if description_images:
        body["images"] = description_images
    return body


class JobImportRequest(BaseModel):
    url: Optional[str] = None
    text: Optional[str] = None
    platform: Optional[str] = None


def _parse_text(text: str) -> dict:
    title = ""
    bracket = re.search(r"[「\[]([^」\]]{2,60})[」\]]", text)
    if bracket:
        title = bracket.group(1).strip()
    else:
        for line in text.splitlines():
            line = line.strip()
            if 4 <= len(line) <= 80 and ("모집" in line or "채용" in line or "알바" in line):
                title = line
                break

    wage = None
    hourly = re.search(r"시급\s*[:：]?\s*([0-9,]{4,7})", text, re.I)
    if hourly:
        wage = f"시급 {hourly.group(1).replace(',', '')}"

    schedule = ""
    time_match = re.search(
        r"(\d{1,2}\s*:\s*\d{2})\s*[~\-–]\s*(\d{1,2}\s*:\s*\d{2})",
        text,
    )
    if time_match:
        schedule = f"{time_match.group(1).replace(' ', '')}-{time_match.group(2).replace(' ', '')}"

    workplace = None
    addr = re.search(
        r"((?:서울|부산|대구|인천|광주|대전|울산|세종|경기|강원|충북|충남|전북|전남|경북|경남|제주)[^\n]{4,60})",
        text,
    )
    if addr:
        workplace = addr.group(1).strip()[:80]

    return {
        "title": title,
        "hourly_wage": wage,
        "work_schedule": schedule,
        "workplace": workplace,
        "job_description": "",
        "raw_text": text,
        "confidence": 0.75 if title else 0.4,
    }


@router.post("/parse")
async def parse_job_import(body: JobImportRequest):
    raw_text = (body.text or "").strip()
    platform = body.platform or "unknown"

    if body.url and not raw_text:
        scraped = await fetch_job_post(body.url, platform=body.platform)
        platform = scraped.platform
        if scraped.error and not scraped.raw_text:
            return {
                "title": "",
                "hourly_wage": None,
                "work_schedule": "",
                "workplace": None,
                "job_description": "",
                "description_body": {},
                "raw_text": "",
                "platform": platform,
                "confidence": 0.0,
                "message": scraped.error,
            }
        desc_body = _description_body_payload(
            description_html=scraped.description_html,
            description_images=scraped.description_images,
        )
        return {
            "title": scraped.title,
            "hourly_wage": scraped.hourly_wage,
            "work_schedule": scraped.work_schedule,
            "workplace": scraped.workplace,
            "job_description": scraped.job_description,
            "description_body": desc_body,
            "raw_text": scraped.raw_text,
            "platform": platform,
            "confidence": scraped.confidence,
            "message": "서버 스크래핑 결과입니다. 등록 전 내용을 확인해 주세요.",
            "source_url": scraped.source_url,
        }

    if body.url:
        platform = detect_platform(body.url)

    if not raw_text:
        return {
            "title": "",
            "hourly_wage": None,
            "work_schedule": "",
            "workplace": None,
            "job_description": "",
            "raw_text": "",
            "platform": platform,
            "confidence": 0.0,
            "message": "url 또는 text가 필요합니다.",
        }

    parsed = _parse_text(raw_text)
    parsed["platform"] = platform
    parsed["message"] = "텍스트 파서 결과입니다."
    return parsed
