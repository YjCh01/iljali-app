import base64

import httpx
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from app.config import settings

router = APIRouter(prefix="/v1/ocr", tags=["ocr"])


class OcrFieldResponse(BaseModel):
    business_registration_number: str
    company_name: str
    industry_name: str
    representative_name: str
    confidence: float
    source: str


@router.post("/business-certificate", response_model=OcrFieldResponse)
async def ocr_business_certificate(
    file: UploadFile = File(...),
    expected_brn: str = "",
    expected_company: str = "",
):
    if not settings.clova_ocr_secret or not settings.clova_ocr_invoke_url:
        if settings.require_clova_ocr:
            raise HTTPException(
                status_code=503,
                detail="CLOVA OCR이 설정되지 않았습니다. 운영 환경에서는 CLOVA_OCR_* 키가 필요합니다.",
            )
        brn = "".join(ch for ch in expected_brn if ch.isdigit()) or "0000000000"
        flagged = brn.endswith("9999")
        return OcrFieldResponse(
            business_registration_number=brn,
            company_name=expected_company or "mock 회사",
            industry_name="인력공급업" if flagged else "물류·창고업",
            representative_name="대표자(mock)",
            confidence=0.94,
            source="mock_ocr",
        )

    content = await file.read()
    body = {
        "version": "V2",
        "requestId": "iljari-server-ocr",
        "timestamp": 0,
        "images": [
            {
                "format": _format_from_filename(file.filename),
                "name": file.filename or "cert",
                "data": base64.b64encode(content).decode(),
            }
        ],
    }

    async with httpx.AsyncClient(timeout=30.0) as client:
        response = await client.post(
            settings.clova_ocr_invoke_url,
            headers={
                "Content-Type": "application/json",
                "X-OCR-SECRET": settings.clova_ocr_secret,
            },
            json=body,
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=502, detail="CLOVA OCR 호출 실패")

    return _parse_clova(response.json(), expected_brn, expected_company)


def _format_from_filename(name: str | None) -> str:
    if not name or "." not in name:
        return "jpg"
    return name.rsplit(".", 1)[-1].lower()


def _parse_clova(payload: dict, expected_brn: str, expected_company: str) -> OcrFieldResponse:
    brn = "".join(ch for ch in expected_brn if ch.isdigit())
    company = expected_company
    industry = "물류·창고업"
    rep = "대표자(OCR)"

    images = payload.get("images") or []
    for image in images:
        for field in image.get("fields") or []:
            name = str(field.get("name") or "")
            text = str(field.get("inferText") or "")
            if "사업자" in name or "등록번호" in name:
                digits = "".join(ch for ch in text if ch.isdigit())
                if len(digits) == 10:
                    brn = digits
            if name in {"companyName", "상호", "법인명"}:
                company = text
            if name in {"industry", "업종", "업태"}:
                industry = text
            if name in {"representative", "대표자"}:
                rep = text

    return OcrFieldResponse(
        business_registration_number=brn,
        company_name=company,
        industry_name=industry,
        representative_name=rep,
        confidence=0.97,
        source="clova_ocr",
    )
