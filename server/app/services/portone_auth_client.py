"""PortOne 본인인증 — Barocert 대안."""

from __future__ import annotations

import uuid
from dataclasses import dataclass

import httpx

from app.config import settings


@dataclass
class PortOneAuthStart:
    tx_id: str
    auth_url: str


@dataclass
class PortOneAuthResult:
    ci: str
    status: str


class PortOneAuthClient:
    @property
    def configured(self) -> bool:
        return bool(settings.portone_api_secret)

    def start_auth(
        self,
        *,
        provider: str,
        session_id: str,
        seeker_email: str,
    ) -> PortOneAuthStart:
        if not self.configured:
            raise RuntimeError("portone_not_configured")

        tx_id = f"po_{uuid.uuid4().hex[:16]}"
        callback = self._callback_url(session_id)
        base = (settings.portone_api_url or "https://api.portone.io").rstrip("/")

        with httpx.Client(timeout=30.0) as client:
            response = client.post(
                f"{base}/identity-verifications",
                headers={
                    "Authorization": f"PortOne {settings.portone_api_secret}",
                    "Content-Type": "application/json",
                },
                json={
                    "channelKey": settings.portone_channel_key or provider,
                    "customer": {"email": seeker_email},
                    "redirectUrl": callback,
                    "customData": {"session_id": session_id},
                },
            )
            if response.status_code >= 400 and settings.portone_allow_mock_fallback:
                return PortOneAuthStart(tx_id=tx_id, auth_url=callback)
            response.raise_for_status()
            body = response.json()

        auth_url = body.get("redirectUrl") or body.get("authUrl") or callback
        return PortOneAuthStart(tx_id=tx_id, auth_url=str(auth_url))

    def verify_callback(self, *, tx_id: str) -> PortOneAuthResult:
        base = (settings.portone_api_url or "https://api.portone.io").rstrip("/")
        with httpx.Client(timeout=30.0) as client:
            response = client.get(
                f"{base}/identity-verifications/{tx_id}",
                headers={"Authorization": f"PortOne {settings.portone_api_secret}"},
            )
            if response.status_code >= 400:
                return PortOneAuthResult(ci="", status="failed")
            body = response.json()

        ci = body.get("ci") or body.get("connectedId")
        if not ci:
            return PortOneAuthResult(ci="", status="failed")
        return PortOneAuthResult(ci=str(ci), status="completed")

    def _callback_url(self, session_id: str) -> str:
        base = settings.simple_auth_callback_url or "http://127.0.0.1:8000/v1/insurance-auth/callback"
        return f"{base}?session_id={session_id}"
