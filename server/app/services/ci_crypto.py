"""CI 등 민감 식별값 암호화·해시 — 원문 최소 보관."""

from __future__ import annotations

import base64
import hashlib
import hmac
import os

from app.config import settings


def hash_ci(ci: str) -> str:
    """검색·중복 확인용 CI 해시 (원문 저장 없음)."""
    key = (settings.insurance_ci_secret or "dev-ci-secret").encode()
    return hmac.new(key, ci.encode(), hashlib.sha256).hexdigest()


def encrypt_ci(ci: str) -> str:
    """서버 전용 재조회용 CI 암호화 (AES-256-GCM)."""
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    secret = settings.insurance_ci_secret or "dev-ci-secret-change-me!!"
    key = hashlib.sha256(secret.encode()).digest()
    nonce = os.urandom(12)
    aes = AESGCM(key)
    ciphertext = aes.encrypt(nonce, ci.encode(), None)
    return base64.urlsafe_b64encode(nonce + ciphertext).decode()


def decrypt_ci(encrypted: str) -> str:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM

    secret = settings.insurance_ci_secret or "dev-ci-secret-change-me!!"
    key = hashlib.sha256(secret.encode()).digest()
    raw = base64.urlsafe_b64decode(encrypted.encode())
    nonce, ciphertext = raw[:12], raw[12:]
    aes = AESGCM(key)
    return aes.decrypt(nonce, ciphertext, None).decode()
