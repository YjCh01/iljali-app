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


_store: dict[str, PhoneVerifyEntry] = {}
_last_sent: dict[str, float] = {}
_SEND_COOLDOWN_SEC = 60


def _normalize(phone: str) -> str:
    return "".join(ch for ch in phone if ch.isdigit())


def normalize_phone(phone: str) -> str:
    return _normalize(phone)


def send_code(phone: str) -> tuple[str, bool]:
    """Returns (masked hint, mock_mode)."""
    normalized = _normalize(phone)
    if len(normalized) < 10:
        raise ValueError("invalid_phone")

    now = time.time()
    last = _last_sent.get(normalized, 0)
    if now - last < _SEND_COOLDOWN_SEC:
        raise ValueError("rate_limited")

    if settings.sms_provider == "mock" or not settings.sms_api_key:
        code = settings.sms_mock_code or "123456"
        mock = True
    else:
        code = f"{random.randint(100000, 999999)}"
        mock = False
        if settings.sms_provider == "aligo":
            message = f"[일자리] 인증번호는 [{code}] 입니다."
            try:
                send_aligo_sms_sync(phone=normalized, message=message)
            except AligoSmsError as exc:
                raise ValueError(f"sms_failed:{exc}") from exc

    _store[normalized] = PhoneVerifyEntry(
        phone=normalized,
        code=code,
        expires_at=time.time() + 180,
    )
    _last_sent[normalized] = now
    return (f"***{normalized[-4:]}", mock)


def verify_code(phone: str, code: str) -> bool:
    normalized = _normalize(phone)
    entry = _store.get(normalized)
    if entry is None or time.time() > entry.expires_at:
        return False
    if entry.code.strip() != code.strip():
        return False
    del _store[normalized]
    return True
