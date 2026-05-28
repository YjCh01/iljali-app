"""Barocert 간편인증 — 네이버·카카오·토스·PASS."""

from __future__ import annotations

import hashlib
import hmac
import json
import logging
import uuid
from dataclasses import dataclass
from datetime import datetime

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

PROVIDER_SERVICE = {
    "naver": "naver",
    "kakao": "kakao",
    "toss": "toss",
    "pass": "pass",
}


@dataclass
class BarocertAuthStart:
    tx_id: str
    auth_url: str


@dataclass
class BarocertAuthResult:
    ci: str
    status: str  # completed | failed


class BarocertClient:
    @property
    def configured(self) -> bool:
        return bool(settings.barocert_link_id and settings.barocert_secret_key)

    def start_auth(
        self,
        *,
        provider: str,
        session_id: str,
        seeker_email: str,
    ) -> BarocertAuthStart:
        if not self.configured:
            raise RuntimeError("barocert_not_configured")

        tx_id = f"tx_{uuid.uuid4().hex[:16]}"
        callback = self._callback_url(session_id)
        service = PROVIDER_SERVICE.get(provider, provider)

        payload = {
            "receiverHP": "",
            "receiverName": seeker_email.split("@")[0],
            "receiverEmail": seeker_email,
            "expiredTime": 600,
            "returnURL": callback,
            "extraData": session_id,
        }

        path = f"/{service}/Sign/{settings.barocert_link_id}"
        body = self._signed_request("POST", path, payload)

        auth_url = (
            body.get("authURL")
            or body.get("authUrl")
            or body.get("scheme")
            or callback
        )
        return BarocertAuthStart(tx_id=tx_id, auth_url=str(auth_url))

    def verify_callback(
        self,
        *,
        provider: str,
        tx_id: str,
        session_id: str,
    ) -> BarocertAuthResult:
        if not self.configured:
            raise RuntimeError("barocert_not_configured")

        service = PROVIDER_SERVICE.get(provider, provider)
        path = f"/{service}/Sign/{settings.barocert_link_id}/{tx_id}"
        body = self._signed_request("GET", path, None)

        ci = body.get("ci") or body.get("connInfo") or body.get("receiptID")
        if not ci:
            return BarocertAuthResult(ci="", status="failed")
        return BarocertAuthResult(ci=str(ci), status="completed")

    def _signed_request(
        self, method: str, path: str, payload: dict | None
    ) -> dict:
        base = (settings.barocert_api_url or "https://api.barocert.com").rstrip("/")
        url = f"{base}{path}"
        body_str = json.dumps(payload) if payload else ""
        timestamp = datetime.utcnow().strftime("%Y%m%d%H%M%S")
        message = f"{method}\n{path}\n{timestamp}\n{body_str}"
        signature = hmac.new(
            settings.barocert_secret_key.encode(),
            message.encode(),
            hashlib.sha256,
        ).hexdigest()

        headers = {
            "Content-Type": "application/json",
            "X-Barocert-Timestamp": timestamp,
            "X-Barocert-Signature": signature,
        }

        with httpx.Client(timeout=30.0) as client:
            if method == "POST":
                response = client.post(url, headers=headers, content=body_str)
            else:
                response = client.get(url, headers=headers)
            if response.status_code >= 400:
                logger.warning("Barocert API %s %s -> %s", method, path, response.text)
                # 개발 환경: Barocert 키만 있고 실 API 미연결 시 mock CI
                if settings.barocert_allow_mock_fallback:
                    return {"ci": f"CI-BAROCERT-{path.split('/')[-1]}"}
                response.raise_for_status()
            return response.json()

    def _callback_url(self, session_id: str) -> str:
        base = settings.simple_auth_callback_url or "http://127.0.0.1:8000/v1/insurance-auth/callback"
        return f"{base}?session_id={session_id}"
