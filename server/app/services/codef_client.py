"""CODEF OAuth + 건강보험 자격득실확인서 REST 클라이언트."""

from __future__ import annotations

import base64
import json
import logging
import time
from dataclasses import dataclass

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

TOKEN_URL = "https://oauth.codef.io/oauth/token"
# CODEF 공공 API — 건강보험 자격득실 (환경별 URL은 codef_api_url로 override)
DEFAULT_CERT_PATH = "/v1/kr/public/pp/nhis/jointCertificate/qualification"


@dataclass
class CodefCertificateData:
    workplace_name: str
    currently_employed: bool


class CodefClient:
    _token: str | None = None
    _token_expires_at: float = 0.0

    def __init__(self) -> None:
        self._base = (settings.codef_api_url or "https://development.codef.io").rstrip("/")

    @property
    def configured(self) -> bool:
        return bool(settings.codef_client_id and settings.codef_client_secret)

    def fetch_qualification(self, *, ci: str) -> CodefCertificateData:
        if not self.configured:
            raise RuntimeError("codef_not_configured")

        token = self._get_token()
        payload = {
            "identity": ci,
            "identityEncYn": "N",
            "telecom": "",
            "loginTypeLevel": "5",  # 간편인증
            "requestType": "0",
        }

        with httpx.Client(timeout=30.0) as client:
            response = client.post(
                f"{self._base}{DEFAULT_CERT_PATH}",
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                content=json.dumps(payload),
            )
            response.raise_for_status()
            body = response.json()

        return self._parse_certificate(body)

    def _get_token(self) -> str:
        now = time.time()
        if self._token and now < self._token_expires_at - 60:
            return self._token

        cred = f"{settings.codef_client_id}:{settings.codef_client_secret}"
        encoded = base64.b64encode(cred.encode()).decode()

        with httpx.Client(timeout=15.0) as client:
            response = client.post(
                TOKEN_URL,
                headers={"Authorization": f"Basic {encoded}"},
                data={"grant_type": "client_credentials", "scope": "read"},
            )
            response.raise_for_status()
            data = response.json()

        self._token = data["access_token"]
        self._token_expires_at = now + int(data.get("expires_in", 3600))
        return self._token

    def _parse_certificate(self, body: dict) -> CodefCertificateData:
        """CODEF 응답 JSON → 사업장명·재직 여부."""
        try:
            result = body.get("data", body)
            if isinstance(result, str):
                result = json.loads(result)
            records = result.get("resQualificationList") or result.get("list") or []
            if not records:
                return CodefCertificateData(workplace_name="", currently_employed=False)

            latest = records[0]
            workplace = (
                latest.get("commCompanyNm")
                or latest.get("companyName")
                or latest.get("workplaceName")
                or ""
            )
            status = (
                latest.get("commStatus")
                or latest.get("employmentStatus")
                or latest.get("status")
                or ""
            )
            employed = str(status) in {"1", "재직", "employed", "Y", "true", "True"}
            return CodefCertificateData(
                workplace_name=str(workplace).strip(),
                currently_employed=employed or bool(workplace),
            )
        except (json.JSONDecodeError, KeyError, TypeError) as exc:
            logger.warning("CODEF parse error: %s body=%s", exc, body)
            raise ValueError("codef_parse_error") from exc
