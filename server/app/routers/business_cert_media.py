"""사업자등록증 사진 업로드 — 서버 저장.

가입 절차 도중(계정 생성 전) 업로드되는 경우가 있어 인증을 요구하지 않는다
(job-media 업로드와 동일한 전례). 실제 보안 경계는 이 URL을 사업자 인증
레코드에 연결하는 `/v1/compliance/business/verify` 쪽에서 담당한다.
"""

from fastapi import APIRouter, File, UploadFile

from app.config import settings
from app.services.media_upload_service import save_uploaded_image

router = APIRouter(prefix="/v1/business-cert-media", tags=["business-cert-media"])


@router.post("/upload")
async def upload_business_cert_media(file: UploadFile = File(...)):
    return await save_uploaded_image(
        file,
        dir_path=settings.business_cert_media_dir,
        url_prefix="/media/business-cert",
    )
