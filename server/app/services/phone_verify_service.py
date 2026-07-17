"""휴대폰 인증 — dev mock / Aligo SMS."""

from __future__ import annotations

import random
import time
from dataclasses import dataclass

from app.config import settings
from app.services.aligo_sms_service import AligoSmsError, send_aligo_sms_sync


@dataclass
class PhoneVerifyEntry:
    phone: str
    code: str
    expires_at: float


@dataclass
class PhoneSendResult:
    hint: str
    mock: bool
    sms_sent: bool


_store: dict[str, PhoneVerifyEntry] = {}
_last_sent: dict[str, float] = {}
# 실제 SMS 재발송 최소 간격(초) — 같은 번호 연타·알리고 스팸 방지용. 번호별 적용.
_RESEND_THROTTLE_SEC = 15
_CODE_TTL_SEC = 180


def _normalize(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def normalize_phone(phone: str) -> str:
    return _normalize(phone)


_SUPPORTED_PROVIDERS = {"aligo"}


def _normalized_provider() -> str:
    return (settings.sms_provider or "mock").strip().lower()


def _mock_mode() -> bool:
    return _normalized_provider() == "mock" or not settings.sms_api_key


def send_code(phone: str) -> PhoneSendResult:
    """인증번호 발송. 유효한 코드가 있으면 재발송 없이 성공(가입↔재설정 공유)."""
    normalized = _normalize(phone)
    if len(normalized) < 10:
        raise ValueError("invalid_phone")

    now = time.time()
    existing = _store.get(normalized)
    if existing is not None and now < existing.expires_at:
        return PhoneSendResult(
            hint=f"***{normalized[-4:]}",
            mock=_mock_mode(),
            sms_sent=False,
        )

    last = _last_sent.get(normalized, 0.0)
    if now - last < _RESEND_THROTTLE_SEC:
        raise ValueError("rate_limited")

    mock = _mock_mode()
    if mock:
        code = settings.sms_mock_code or "123456"
    else:
        code = f"{random.randint(100000, 999999)}"
        provider = _normalized_provider()
        if provider == "aligo":
            message = f"[일자리] 본인인증 [{code}] 를 입력해주세요."
            try:
                send_aligo_sms_sync(phone=normalized, message=message)
            except AligoSmsError as exc:
                raise ValueError(f"sms_failed:{exc}") from exc
        else:
            # 알 수 없는(오타 포함) SMS_PROVIDER 값 — 문자를 실제로 보내지 않고
            # "발송 성공"으로 응답하는 조용한 실패를 막기 위해 명시적으로 막는다.
            raise ValueError(f"sms_provider_unsupported:{provider}")

    _store[normalized] = PhoneVerifyEntry(
        phone=normalized,
        code=code,
        expires_at=now + _CODE_TTL_SEC,
    )
    _last_sent[normalized] = now
    return PhoneSendResult(
        hint=f"***{normalized[-4:]}",
        mock=mock,
        sms_sent=True,
    )


def verify_code(phone: str, code: str) -> bool:
    normalized = _normalize(phone)
    entry = _store.get(normalized)
    if entry is None or time.time() > entry.expires_at:
        return False
    if entry.code.strip() != code.strip():
        return False
    del _store[normalized]
    # 인증 완료 후 비밀번호 재설정 등 다음 단계에서 바로 새 문자 발송 가능
    _last_sent.pop(normalized, None)
    return True
