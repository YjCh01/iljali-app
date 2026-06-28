"""HMAC 기반 세션 토큰 (JWT 대체 — 추가 의존성 없음)."""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
from typing import Any

from app.config import settings

TOKEN_TTL_SEC = 60 * 60 * 24 * 7  # 7 days
PHONE_VERIFY_TTL_SEC = 60 * 60  # 60 minutes — 다단계 가입 완료까지


def _secret() -> bytes:
    raw = settings.auth_token_secret or settings.admin_api_key or "iljari-dev-secret"
    return raw.encode("utf-8")


def issue_token(payload: dict[str, Any], *, ttl_sec: int = TOKEN_TTL_SEC) -> str:
    body = {
        **payload,
        "exp": int(time.time()) + ttl_sec,
    }
    encoded = base64.urlsafe_b64encode(
        json.dumps(body, separators=(",", ":")).encode("utf-8")
    ).decode("ascii").rstrip("=")
    sig = hmac.new(_secret(), encoded.encode("ascii"), hashlib.sha256).hexdigest()
    return f"{encoded}.{sig}"


def verify_token(token: str) -> dict[str, Any] | None:
    if not token or "." not in token:
        return None
    encoded, sig = token.split(".", 1)
    expected = hmac.new(_secret(), encoded.encode("ascii"), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, sig):
        return None
    pad = "=" * (-len(encoded) % 4)
    try:
        body = json.loads(base64.urlsafe_b64decode(encoded + pad))
    except (json.JSONDecodeError, ValueError):
        return None
    exp = body.get("exp")
    if not isinstance(exp, int) or exp < int(time.time()):
        return None
    return body


def issue_phone_verified_token(phone: str, *, purpose: str) -> str:
    return issue_token(
        {
            "typ": "phone_verified",
            "purpose": purpose,
            "phone": phone,
        },
        ttl_sec=PHONE_VERIFY_TTL_SEC,
    )


def verify_phone_verified_token(token: str, *, phone: str, purpose: str) -> bool:
    payload = verify_token(token)
    if payload is None:
        return False
    if payload.get("typ") != "phone_verified":
        return False
    if payload.get("purpose") != purpose:
        return False
    return payload.get("phone") == phone
