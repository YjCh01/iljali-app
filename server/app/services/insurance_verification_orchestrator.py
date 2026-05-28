"""건강보험 간편인증 + 자격득실 조회 + 사업장명 검증 오케스트레이션."""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from app.config import settings
from app.insurance_auth_models import InsuranceAuthSession, MonthlyReemployment
from app.permanent_commission_models import InsuranceVerificationLog, PermanentEmployment
from app.services.ci_crypto import decrypt_ci, encrypt_ci, hash_ci
from app.services.insurance_certificate_service import InsuranceCertificateService
from app.services.simple_auth_service import SimpleAuthService

VERIFICATION_VALIDITY_DAYS = 30
COMMISSION_RATE = 0.055


def _normalize_company_name(value: str) -> str:
    return (
        value.replace(" ", "")
        .replace("(주)", "")
        .replace("주식회사", "")
        .lower()
    )


def company_name_matches(workplace: str, employer: str) -> bool:
    w = _normalize_company_name(workplace)
    e = _normalize_company_name(employer)
    if not w or not e:
        return False
    return w in e or e in w


class InsuranceVerificationOrchestrator:
    def __init__(self) -> None:
        self._auth = SimpleAuthService()
        self._cert = InsuranceCertificateService()

    def start_auth_session(
        self,
        db: Session,
        *,
        employment_id: str,
        seeker_email: str,
        auth_provider: str,
    ) -> dict:
        employment = (
            db.query(PermanentEmployment)
            .filter(PermanentEmployment.employment_id == employment_id)
            .first()
        )
        if employment is None:
            raise ValueError("employment_not_found")

        session = self._auth.start(provider=auth_provider, seeker_email=seeker_email)

        row = InsuranceAuthSession(
            session_id=session.session_id,
            employment_id=employment_id,
            seeker_email=seeker_email,
            auth_provider=auth_provider,
            auth_backend=session.backend,
            status="pending",
            external_tx_id=session.external_tx_id,
        )
        db.add(row)
        db.commit()

        return {
            "session_id": session.session_id,
            "auth_provider": auth_provider,
            "auth_backend": session.backend,
            "auth_url": session.auth_url,
            "status": session.status,
            "mock_complete_available": session.backend == "mock",
            "requires_webview": session.auth_url is not None,
        }

    def complete_auth_and_verify(
        self,
        db: Session,
        *,
        session_id: str,
        mock_ci: str | None = None,
    ) -> dict:
        row = (
            db.query(InsuranceAuthSession)
            .filter(InsuranceAuthSession.session_id == session_id)
            .first()
        )
        if row is None:
            raise ValueError("session_not_found")

        employment = (
            db.query(PermanentEmployment)
            .filter(PermanentEmployment.employment_id == row.employment_id)
            .first()
        )
        if employment is None:
            raise ValueError("employment_not_found")

        if row.auth_backend == "mock":
            if not mock_ci:
                mock_ci = f"CI-MOCK-{row.seeker_email}"
            session = self._auth.complete_mock(session_id, ci=mock_ci)
        else:
            session = self._auth.get(session_id)
            if session is None:
                raise ValueError("session_not_found")
            if session.status != "completed" or not session.ci:
                raise ValueError("auth_not_completed")

        ci = session.ci
        assert ci

        row.status = "completed"
        row.ci_hash = hash_ci(ci)
        row.ci_encrypted = encrypt_ci(ci)
        row.completed_at = datetime.utcnow()
        db.commit()

        return self._fetch_and_verify(
            db,
            employment=employment,
            ci=ci,
            auth_provider=row.auth_provider,
            session_id=session_id,
        )

    def reverify_employment(
        self,
        db: Session,
        *,
        employment_id: str,
        cycle_number: int,
        period_start: datetime,
        period_end: datetime,
    ) -> dict:
        employment = (
            db.query(PermanentEmployment)
            .filter(PermanentEmployment.employment_id == employment_id)
            .first()
        )
        if employment is None:
            raise ValueError("employment_not_found")

        auth_row = (
            db.query(InsuranceAuthSession)
            .filter(
                InsuranceAuthSession.employment_id == employment_id,
                InsuranceAuthSession.status == "completed",
                InsuranceAuthSession.ci_encrypted.isnot(None),
            )
            .order_by(InsuranceAuthSession.completed_at.desc())
            .first()
        )
        if auth_row is None or not auth_row.ci_encrypted:
            reemp = MonthlyReemployment(
                reemployment_id=f"re_{uuid.uuid4().hex[:12]}",
                employment_id=employment_id,
                cycle_number=cycle_number,
                period_start=period_start,
                period_end=period_end,
                status="failed",
                failure_reason="CI 없음 — 구직자 재인증 필요",
            )
            db.add(reemp)
            db.commit()
            return {"success": False, "reason": reemp.failure_reason}

        ci = decrypt_ci(auth_row.ci_encrypted)
        result = self._fetch_and_verify(
            db,
            employment=employment,
            ci=ci,
            auth_provider=auth_row.auth_provider,
            session_id=auth_row.session_id,
            cycle_number=cycle_number,
            period_start=period_start,
            period_end=period_end,
        )
        return result

    def handle_auth_callback(
        self,
        db: Session,
        *,
        session_id: str,
        provider: str | None = None,
        tx_id: str | None = None,
        ci: str | None = None,
    ) -> dict:
        row = (
            db.query(InsuranceAuthSession)
            .filter(InsuranceAuthSession.session_id == session_id)
            .first()
        )
        if row is None:
            raise ValueError("session_not_found")

        session = self._auth.handle_callback(
            session_id=session_id,
            provider=provider or row.auth_provider,
            tx_id=tx_id or row.external_tx_id,
            ci=ci,
        )

        if session.status == "completed" and session.ci:
            row.status = "completed"
            row.ci_hash = hash_ci(session.ci)
            row.ci_encrypted = encrypt_ci(session.ci)
            row.completed_at = datetime.utcnow()
            db.commit()

        scheme = settings.app_deep_link_scheme
        return {
            "session_id": session_id,
            "status": session.status,
            "redirect_url": (
                f"{scheme}://insurance-auth/success?session_id={session_id}"
                if session.status == "completed"
                else f"{scheme}://insurance-auth/fail?session_id={session_id}"
            ),
        }

    def _fetch_and_verify(
        self,
        db: Session,
        *,
        employment: PermanentEmployment,
        ci: str,
        auth_provider: str,
        session_id: str,
        cycle_number: int = 0,
        period_start: datetime | None = None,
        period_end: datetime | None = None,
    ) -> dict:
        now = datetime.utcnow()
        cert = self._cert.fetch(
            ci=ci, employer_company_name=employment.company_name
        )
        matched = company_name_matches(cert.workplace_name, employment.company_name)
        success = matched and cert.currently_employed

        log_id = f"ins_{uuid.uuid4().hex[:12]}"
        log = InsuranceVerificationLog(
            log_id=log_id,
            employment_id=employment.employment_id,
            workplace_name=cert.workplace_name,
            employer_company_name=employment.company_name,
            company_name_matched=matched,
            employed_confirmed=cert.currently_employed,
            verified_at=now,
            expires_at=now + timedelta(days=VERIFICATION_VALIDITY_DAYS),
            status="verified" if success else "rejected",
            method=f"{auth_provider}_simple_auth",
            rejection_reason=None
            if success
            else (
                "사업장명 불일치"
                if not matched
                else "재직 상태 미확인"
            ),
            ci_hash=hash_ci(ci),
            auth_provider=auth_provider,
            certificate_provider=cert.provider,
            cycle_number=cycle_number,
            simple_auth_session_id=session_id,
        )
        db.add(log)

        reemp_status = "verified" if success else "failed"
        if cycle_number > 0 and period_start and period_end:
            reemp = MonthlyReemployment(
                reemployment_id=f"re_{uuid.uuid4().hex[:12]}",
                employment_id=employment.employment_id,
                cycle_number=cycle_number,
                period_start=period_start,
                period_end=period_end,
                verification_log_id=log_id,
                status=reemp_status,
                failure_reason=None if success else log.rejection_reason,
            )
            db.add(reemp)

        db.commit()

        return {
            "success": success,
            "log_id": log_id,
            "workplace_name": cert.workplace_name,
            "company_name_matched": matched,
            "employed_confirmed": cert.currently_employed,
            "verified_at": now.isoformat(),
            "expires_at": log.expires_at.isoformat(),
            "status": log.status,
            "certificate_provider": cert.provider,
            "auth_provider": auth_provider,
            "cycle_number": cycle_number,
            "rejection_reason": log.rejection_reason,
            "expected_commission_krw": round(
                employment.monthly_salary_krw * COMMISSION_RATE
            )
            if success
            else 0,
        }
