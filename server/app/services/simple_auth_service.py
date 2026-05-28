"""간편인증 — Barocert / PortOne / mock."""

from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import datetime, timedelta

from app.config import settings
from app.services.barocert_client import BarocertClient
from app.services.portone_auth_client import PortOneAuthClient


@dataclass
class SimpleAuthSession:
    session_id: str
    provider: str
    auth_url: str | None
    status: str  # pending | completed | failed
    ci: str | None = None
    expires_at: datetime | None = None
    backend: str = "mock"
    external_tx_id: str | None = None


class SimpleAuthService:
    _sessions: dict[str, SimpleAuthSession] = {}

    def __init__(self) -> None:
        self._barocert = BarocertClient()
        self._portone = PortOneAuthClient()

    def start(self, *, provider: str, seeker_email: str) -> SimpleAuthSession:
        session_id = f"sauth_{uuid.uuid4().hex[:16]}"
        expires_at = datetime.utcnow() + timedelta(minutes=10)

        if self._barocert.configured:
            start = self._barocert.start_auth(
                provider=provider,
                session_id=session_id,
                seeker_email=seeker_email,
            )
            session = SimpleAuthSession(
                session_id=session_id,
                provider=provider,
                auth_url=start.auth_url,
                status="pending",
                expires_at=expires_at,
                backend="barocert",
                external_tx_id=start.tx_id,
            )
        elif self._portone.configured:
            start = self._portone.start_auth(
                provider=provider,
                session_id=session_id,
                seeker_email=seeker_email,
            )
            session = SimpleAuthSession(
                session_id=session_id,
                provider=provider,
                auth_url=start.auth_url,
                status="pending",
                expires_at=expires_at,
                backend="portone",
                external_tx_id=start.tx_id,
            )
        else:
            session = SimpleAuthSession(
                session_id=session_id,
                provider=provider,
                auth_url=None,
                status="pending",
                expires_at=expires_at,
                backend="mock",
            )

        self._sessions[session_id] = session
        return session

    def complete_from_callback(
        self,
        session_id: str,
        *,
        ci: str,
        tx_id: str | None = None,
    ) -> SimpleAuthSession:
        session = self._sessions.get(session_id)
        if session is None:
            raise KeyError("session_not_found")
        session.status = "completed"
        session.ci = ci
        if tx_id:
            session.external_tx_id = tx_id
        return session

    def complete_mock(self, session_id: str, *, ci: str) -> SimpleAuthSession:
        return self.complete_from_callback(session_id, ci=ci)

    def handle_callback(
        self,
        *,
        session_id: str,
        provider: str | None = None,
        tx_id: str | None = None,
        ci: str | None = None,
    ) -> SimpleAuthSession:
        session = self._sessions.get(session_id)
        if session is None:
            raise KeyError("session_not_found")

        if ci:
            return self.complete_from_callback(session_id, ci=ci, tx_id=tx_id)

        effective_tx = tx_id or session.external_tx_id
        if session.backend == "barocert" and effective_tx:
            result = self._barocert.verify_callback(
                provider=provider or session.provider,
                tx_id=effective_tx,
                session_id=session_id,
            )
            if result.status == "completed" and result.ci:
                return self.complete_from_callback(
                    session_id, ci=result.ci, tx_id=effective_tx
                )
        elif session.backend == "portone" and effective_tx:
            result = self._portone.verify_callback(tx_id=effective_tx)
            if result.status == "completed" and result.ci:
                return self.complete_from_callback(
                    session_id, ci=result.ci, tx_id=effective_tx
                )

        session.status = "failed"
        return session

    def get(self, session_id: str) -> SimpleAuthSession | None:
        return self._sessions.get(session_id)
