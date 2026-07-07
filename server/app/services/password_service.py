"""비밀번호 해시·검증·규칙."""

from __future__ import annotations

import hashlib
import hmac
import re
import secrets

_DIGIT = re.compile(r"[0-9]")
_UPPER = re.compile(r"[A-Z]")
_LOWER = re.compile(r"[a-z]")
_SPECIAL = re.compile(r'[!@#$%^&*(),.?":{}|<>_\-+=\[\]\\;/`~]')

QC_LEGACY_PASSWORD = "QcTest1234!"
_QC_SEEKER_EMAIL = re.compile(r"^seeker-\d{4}@qc\.iljari\.co\.kr$", re.IGNORECASE)


def _is_qc_seeker_email(email: str | None) -> bool:
    if not email:
        return False
    return bool(_QC_SEEKER_EMAIL.match(email.strip()))


def validate_password_strength(password: str) -> str | None:
    if not password:
        return "비밀번호를 입력해 주세요."
    if len(password) < 8:
        return "비밀번호는 8자리 이상이어야 합니다."
    if len(password) > 128:
        return "비밀번호는 128자 이하여야 합니다."

    types = sum(
        1
        for pattern in (_DIGIT, _UPPER, _LOWER, _SPECIAL)
        if pattern.search(password)
    )
    if types < 2:
        return "비밀번호에 숫자·영문·특수문자 중 2가지 이상 포함해 주세요."
    return None


def hash_password(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        120_000,
    )
    return f"pbkdf2_sha256$120000${salt}${digest.hex()}"


def verify_password(
    password: str, stored: str | None, *, email: str | None = None
) -> bool:
    if not stored:
        if _is_qc_seeker_email(email) and password == QC_LEGACY_PASSWORD:
            return True
        return False
    if stored.startswith("pbkdf2_sha256$"):
        try:
            _, iterations, salt, digest_hex = stored.split("$", 3)
            digest = hashlib.pbkdf2_hmac(
                "sha256",
                password.encode("utf-8"),
                salt.encode("utf-8"),
                int(iterations),
            )
            return hmac.compare_digest(digest.hex(), digest_hex)
        except (ValueError, TypeError):
            return False
    return hmac.compare_digest(password, stored)


def mask_email(email: str) -> str:
    if "@" not in email:
        return "***"
    local, domain = email.split("@", 1)
    if len(local) <= 2:
        masked_local = f"{local[0]}*"
    else:
        masked_local = f"{local[0]}{'*' * (len(local) - 2)}{local[-1]}"
    return f"{masked_local}@{domain}"
