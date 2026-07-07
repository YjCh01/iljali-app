"""이메일 6자리 인증 — mock 또는 로그(운영 시 SMTP 연동)."""

from __future__ import annotations

import random
import time
from dataclasses import dataclass

from app.config import settings

_SEND_COOLDOWN_SEC = 60


@dataclass
class EmailVerifyEntry:
    email: str
    code: str
    expires_at: float


_store: dict[str, EmailVerifyEntry] = {}
_last_sent: dict[str, float] = {}


def normalize_email(email: str) -> str:
    return email.strip().lower()


def send_code(email: str) -> tuple[str, bool]:
    """Returns (masked hint, mock_mode)."""
    normalized = normalize_email(email)
    if "@" not in normalized:
        raise ValueError("invalid_email")

    now = time.time()
    last = _last_sent.get(normalized, 0)
    if now - last < _SEND_COOLDOWN_SEC:
        raise ValueError("rate_limited")

    mock = settings.sms_provider == "mock" or not settings.sms_api_key
    if mock:
        code = settings.sms_mock_code or "123456"
    else:
        code = f"{random.randint(100000, 999999)}"
        # TODO: SMTP/SendGrid 연동 — 현재는 mock과 동일하게 메모리만 저장
        mock = True

    _store[normalized] = EmailVerifyEntry(
        email=normalized,
        code=code,
        expires_at=time.time() + 180,
    )
    _last_sent[normalized] = now
    local, _, domain = normalized.partition("@")
    masked = f"{local[:2]}***@{domain}" if local else normalized
    return masked, mock


def verify_code(email: str, code: str) -> bool:
    normalized = normalize_email(email)
    entry = _store.get(normalized)
    if entry is None or time.time() > entry.expires_at:
        return False
    if entry.code.strip() != code.strip():
        return False
    return True
