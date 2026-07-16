"""자격증 사진 업로드 — 인증된 본인만, 서버 저장."""

from fastapi import APIRouter, File, Header, UploadFile

from app.config import settings
from app.routers.job_board import _resolve_bearer
from app.services.media_upload_service import save_uploaded_image

router = APIRouter(prefix="/v1/credential-media", tags=["credential-media"])


@router.post("/upload")
async def upload_credential_media(
    file: UploadFile = File(...),
    authorization: str | None = Header(default=None),
):
    _resolve_bearer(authorization)
    return await save_uploaded_image(
        file,
        dir_path=settings.credential_media_dir,
        url_prefix="/media/credential",
    )
