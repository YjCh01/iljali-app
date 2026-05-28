"""건강보험 자격득실확인서 조회 — CODEF / Hyphen / mock."""

from __future__ import annotations

import logging
from dataclasses import dataclass

from app.services.codef_client import CodefClient
from app.services.hyphen_client import HyphenClient

logger = logging.getLogger(__name__)


@dataclass
class CertificateResult:
    workplace_name: str
    currently_employed: bool
    provider: str  # codef | hyphen | mock


class InsuranceCertificateService:
    def __init__(self) -> None:
        self._codef = CodefClient()
        self._hyphen = HyphenClient()

    def fetch(self, *, ci: str, employer_company_name: str) -> CertificateResult:
        if self._codef.configured:
            try:
                data = self._codef.fetch_qualification(ci=ci)
                return CertificateResult(
                    workplace_name=data.workplace_name or employer_company_name,
                    currently_employed=data.currently_employed,
                    provider="codef",
                )
            except Exception as exc:
                logger.warning("CODEF fetch failed, fallback: %s", exc)

        if self._hyphen.configured:
            try:
                data = self._hyphen.fetch_qualification(ci=ci)
                return CertificateResult(
                    workplace_name=data.workplace_name or employer_company_name,
                    currently_employed=data.currently_employed,
                    provider="hyphen",
                )
            except Exception as exc:
                logger.warning("Hyphen fetch failed, fallback: %s", exc)

        return self._fetch_mock(ci=ci, employer_company_name=employer_company_name)

    def _fetch_mock(self, *, ci: str, employer_company_name: str) -> CertificateResult:
        suffix = hash(ci) % 10
        employed = suffix != 9
        return CertificateResult(
            workplace_name=employer_company_name if employed else "타사업장",
            currently_employed=employed,
            provider="mock",
        )
