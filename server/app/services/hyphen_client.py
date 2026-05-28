"""Hyphen API — 건강보험 자격득실확인서 (CODEF 대안)."""

from __future__ import annotations

import logging
from dataclasses import dataclass

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


@dataclass
class HyphenCertificateData:
    workplace_name: str
    currently_employed: bool


class HyphenClient:
    @property
    def configured(self) -> bool:
        return bool(settings.hyphen_api_key)

    def fetch_qualification(self, *, ci: str) -> HyphenCertificateData:
        if not self.configured:
            raise RuntimeError("hyphen_not_configured")

        url = settings.hyphen_api_url or "https://api.hyphen.im/in0112000936"
        with httpx.Client(timeout=30.0) as client:
            response = client.post(
                url,
                headers={
                    "Authorization": f"Bearer {settings.hyphen_api_key}",
                    "Content-Type": "application/json",
                },
                json={"ci": ci, "docType": "nhis_qualification"},
            )
            response.raise_for_status()
            body = response.json()

        data = body.get("data", body)
        workplace = str(
            data.get("companyName") or data.get("workplaceName") or ""
        ).strip()
        employed = bool(data.get("employed", data.get("currentlyEmployed", False)))
        return HyphenCertificateData(
            workplace_name=workplace,
            currently_employed=employed,
        )
