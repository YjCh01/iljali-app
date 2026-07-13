"""이력서 PDF·이미지 → 텍스트 추출."""

from __future__ import annotations

import base64
import io
import re

import httpx

from app.config import settings

_MOCK_RESUME_TEXT = """
학력
서울대학교 경영학과 졸업 2016-2020

경력
(주)아라물류 물류센터 피킹 2021.03 - 2023.12
이마트24 매장 보조 아르바이트 2019.06 - 2020.02

면허
운전면허 1종 보통

자격증
지게차운전기능사 2022.05
한국사능력검정시험 2급

자기소개
성실하고 체력이 좋아 현장 업무에 자신 있습니다.
"""


def _format_from_filename(name: str | None) -> str:
    if not name or "." not in name:
        return "jpg"
    ext = name.rsplit(".", 1)[-1].lower()
    return "pdf" if ext == "pdf" else ext


def _extract_pdf_text(content: bytes) -> str:
    try:
        from pypdf import PdfReader
    except ImportError as error:
        raise ValueError("PDF 처리를 위해 서버에 pypdf가 필요합니다.") from error

    reader = PdfReader(io.BytesIO(content))
    parts: list[str] = []
    for page in reader.pages:
        text = page.extract_text() or ""
        if text.strip():
            parts.append(text.strip())
    return "\n".join(parts).strip()


def _extract_clova_plain_text(payload: dict) -> str:
    chunks: list[str] = []
    for image in payload.get("images") or []:
        for field in image.get("fields") or []:
            text = str(field.get("inferText") or "").strip()
            if text:
                chunks.append(text)
        for table in image.get("tables") or []:
            for cell in table.get("cells") or []:
                for line in cell.get("cellTextLines") or []:
                    for word in line.get("cellWords") or []:
                        text = str(word.get("inferText") or "").strip()
                        if text:
                            chunks.append(text)
    return "\n".join(chunks).strip()


async def _ocr_image_bytes(content: bytes, *, filename: str) -> tuple[str, str]:
    if not settings.clova_ocr_secret or not settings.clova_ocr_invoke_url:
        return _MOCK_RESUME_TEXT.strip(), "mock_ocr"

    body = {
        "version": "V2",
        "requestId": "iljari-resume-ocr",
        "timestamp": 0,
        "images": [
            {
                "format": _format_from_filename(filename),
                "name": filename or "resume",
                "data": base64.b64encode(content).decode(),
            }
        ],
    }
    async with httpx.AsyncClient(timeout=45.0) as client:
        response = await client.post(
            settings.clova_ocr_invoke_url,
            headers={
                "Content-Type": "application/json",
                "X-OCR-SECRET": settings.clova_ocr_secret,
            },
            json=body,
        )
    if response.status_code >= 400:
        raise ValueError("이미지 OCR 호출에 실패했습니다.")
    text = _extract_clova_plain_text(response.json())
    if not text:
        raise ValueError("이미지에서 텍스트를 찾지 못했습니다.")
    return text, "clova_ocr"


async def extract_resume_document_text(
    content: bytes,
    *,
    filename: str,
) -> tuple[str, str]:
    if not content:
        raise ValueError("파일이 비어 있습니다.")

    lower = (filename or "").lower()
    if lower.endswith(".pdf"):
        text = _extract_pdf_text(content)
        if not text:
            raise ValueError("PDF에서 텍스트를 추출하지 못했습니다. 스캔본이면 캡처 이미지로 올려 주세요.")
        return text, "pdf_text"

    if re.search(r"\.(png|jpe?g|webp|heic|bmp)$", lower):
        return await _ocr_image_bytes(content, filename=filename)

    raise ValueError("지원 형식: PDF, PNG, JPG")
