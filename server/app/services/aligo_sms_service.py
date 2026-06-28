"""Aligo SMS 발송 (https://smartsms.aligo.in/)."""

from __future__ import annotations

import httpx

from app.config import settings


class AligoSmsError(Exception):
    pass


async def send_aligo_sms(*, phone: str, message: str) -> None:
    _send_aligo_sms_sync(phone=phone, message=message)


def send_aligo_sms_sync(*, phone: str, message: str) -> None:
    user_id = settings.sms_aligo_user_id.strip()
    api_key = settings.sms_api_key.strip()
    sender = settings.sms_sender_id.strip()
    if not user_id or not api_key or not sender:
        raise AligoSmsError(
            "Aligo SMS 설정이 비어 있습니다 "
            "(SMS_ALIGO_USER_ID, SMS_API_KEY, SMS_SENDER_ID)"
        )

    payload = {
        "key": api_key,
        "user_id": user_id,
        "sender": sender,
        "receiver": phone,
        "msg": message,
        "msg_type": "SMS",
        "title": "일자리 인증",
    }
    with httpx.Client(timeout=15.0) as client:
        response = client.post("https://apis.aligo.in/send/", data=payload)
    if response.status_code >= 400:
        raise AligoSmsError(f"Aligo HTTP {response.status_code}")
    body = response.json()
    if str(body.get("result_code")) not in {"1", "0"}:
        raise AligoSmsError(str(body.get("message") or "Aligo 발송 실패"))
