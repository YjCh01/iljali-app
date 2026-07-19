"""구직자 이력서 AI 불러오기 — URL·텍스트·파일(PDF/이미지)."""

from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, File, Form, Header, HTTPException, UploadFile
from pydantic import BaseModel

from app.routers.job_board import _resolve_bearer
from app.services.resume_document_service import extract_resume_document_text
from app.services.resume_text_parser import parse_resume_text
from app.services.resume_url_fetcher import detect_resume_platform, fetch_resume_url_text

router = APIRouter(prefix="/v1/resume-import", tags=["resume-import"])


def _assert_seeker(payload: dict) -> None:
    if str(payload.get("member_type", "")) != "seeker":
        raise HTTPException(status_code=403, detail="구직자 본인만 이용할 수 있습니다.")


class ResumeImportRequest(BaseModel):
    url: Optional[str] = None
    text: Optional[str] = None
    platform: Optional[str] = None


def _response_from_text(
    *,
    text: str,
    platform: str,
    source: str,
    message: str,
) -> dict:
    parsed = parse_resume_text(text)
    return {
        **parsed,
        "platform": platform,
        "source": source,
        "message": message,
    }


@router.post("/parse")
async def parse_resume_import(
    body: ResumeImportRequest,
    authorization: str | None = Header(default=None),
):
    payload = _resolve_bearer(authorization)
    _assert_seeker(payload)
    raw_text = (body.text or "").strip()
    platform = body.platform or "unknown"

    if body.url and not raw_text:
        fetched, detected, error = await fetch_resume_url_text(body.url)
        platform = detected or detect_resume_platform(body.url)
        if error and not fetched:
            return {
                "educations": [],
                "experiences": [],
                "licenses": [],
                "certifications": [],
                "selfIntroduction": "",
                "raw_text": "",
                "platform": platform,
                "confidence": 0.0,
                "source": "url_fetch",
                "message": error,
            }
        return _response_from_text(
            text=fetched,
            platform=platform,
            source="url_fetch",
            message="URL에서 읽은 내용입니다. 로그인 페이지일 수 있으니 반드시 확인해 주세요.",
        )

    if body.url:
        platform = detect_resume_platform(body.url)

    if not raw_text:
        raise HTTPException(status_code=400, detail="url, text, 또는 파일 업로드가 필요합니다.")

    return _response_from_text(
        text=raw_text,
        platform=platform,
        source="text",
        message="붙여넣은 텍스트를 분석했습니다. 항목을 확인한 뒤 저장해 주세요.",
    )


@router.post("/parse-file")
async def parse_resume_import_file(
    file: UploadFile = File(...),
    platform: str = Form(default="unknown"),
    authorization: str | None = Header(default=None),
):
    payload = _resolve_bearer(authorization)
    _assert_seeker(payload)
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="파일이 비어 있습니다.")
    try:
        text, source = await extract_resume_document_text(
            content,
            filename=file.filename or "resume",
        )
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error)) from error

    return _response_from_text(
        text=text,
        platform=platform,
        source=source,
        message="파일에서 텍스트를 추출했습니다. 인식 결과를 확인해 주세요.",
    )
