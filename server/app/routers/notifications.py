from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter(prefix="/v1/notifications", tags=["notifications"])


class AlimtalkRequest(BaseModel):
    template_code: str
    recipient_phone: str
    recipient_name: str = ""
    variables: dict[str, str] = Field(default_factory=dict)
    fallback_body: str = ""


@router.post("/alimtalk")
async def send_alimtalk(body: AlimtalkRequest):
    """
    카카오 알림톡 발송 프록시 (MVP).

    실서비스: 카카오 비즈메시지 API 키·템플릿 승인 후 이 엔드포인트에서 발송.
    현재는 수신 내용을 로그로 기록하고 delivered=true 로 응답합니다.
    """
    # TODO: Kakao Bizmessage API 연동 (sender key, template code)
    print(
        "[alimtalk]",
        body.template_code,
        body.recipient_phone,
        body.fallback_body,
    )
    return {
        "delivered": True,
        "channel": "kakao_alimtalk_mock",
        "message": body.fallback_body,
    }
