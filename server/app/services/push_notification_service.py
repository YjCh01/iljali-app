from __future__ import annotations

import json
import math
from datetime import datetime, timezone
from uuid import uuid4

import httpx
from google.auth.transport.requests import Request
from google.oauth2 import service_account
from sqlalchemy.orm import Session

from app.config import settings
from app.notification_models import DevicePushTokenRow


def _haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    radius = 6_371_000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    d_lat = math.radians(lat2 - lat1)
    d_lng = math.radians(lng2 - lng1)
    a = (
        math.sin(d_lat / 2) ** 2
        + math.cos(p1) * math.cos(p2) * math.sin(d_lng / 2) ** 2
    )
    return 2 * radius * math.asin(math.sqrt(a))


class FcmService:
    def __init__(self) -> None:
        self._credentials = None
        self._project_id: str | None = None
        raw = (settings.fcm_service_account_json or "").strip()
        if raw:
            info = json.loads(raw)
            self._project_id = info.get("project_id")
            self._credentials = service_account.Credentials.from_service_account_info(
                info,
                scopes=["https://www.googleapis.com/auth/firebase.messaging"],
            )

    @property
    def enabled(self) -> bool:
        return self._credentials is not None and bool(self._project_id)

    def _access_token(self) -> str:
        assert self._credentials is not None
        if not self._credentials.valid:
            self._credentials.refresh(Request())
        return self._credentials.token

    def send_to_token(
        self,
        token: str,
        *,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> bool:
        if not self.enabled or not token.strip():
            return False
        payload = {
            "message": {
                "token": token,
                "notification": {"title": title, "body": body},
                "data": {k: str(v) for k, v in (data or {}).items()},
                "webpush": {
                    "headers": {"Urgency": "high"},
                    "notification": {
                        "title": title,
                        "body": body,
                        "icon": "/icons/Icon-192.png",
                    },
                },
            }
        }
        url = (
            f"https://fcm.googleapis.com/v1/projects/{self._project_id}/messages:send"
        )
        headers = {
            "Authorization": f"Bearer {self._access_token()}",
            "Content-Type": "application/json",
        }
        try:
            with httpx.Client(timeout=10.0) as client:
                response = client.post(url, headers=headers, json=payload)
                if response.status_code == 404:
                    return False
                response.raise_for_status()
                return True
        except httpx.HTTPError:
            return False

    def send_to_tokens(
        self,
        tokens: list[str],
        *,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> dict[str, int]:
        sent = 0
        failed = 0
        for token in tokens:
            if self.send_to_token(token, title=title, body=body, data=data):
                sent += 1
            else:
                failed += 1
        return {"sent": sent, "failed": failed}


fcm_service = FcmService()


def register_device_token(
    db: Session,
    *,
    member_email: str,
    member_type: str,
    fcm_token: str,
    platform: str = "web",
    chat_enabled: bool = True,
    job_alerts_enabled: bool = True,
    application_updates_enabled: bool = True,
) -> dict:
    email = member_email.strip().lower()
    token = fcm_token.strip()
    existing = (
        db.query(DevicePushTokenRow)
        .filter(DevicePushTokenRow.fcm_token == token)
        .first()
    )
    now = datetime.now(timezone.utc).replace(tzinfo=None)
    if existing is not None:
        existing.member_email = email
        existing.member_type = member_type
        existing.platform = platform
        existing.chat_enabled = chat_enabled
        existing.job_alerts_enabled = job_alerts_enabled
        existing.application_updates_enabled = application_updates_enabled
        existing.updated_at = now
        row = existing
    else:
        row = DevicePushTokenRow(
            id=f"devtok_{uuid4().hex[:12]}",
            member_email=email,
            member_type=member_type,
            fcm_token=token,
            platform=platform,
            chat_enabled=chat_enabled,
            job_alerts_enabled=job_alerts_enabled,
            application_updates_enabled=application_updates_enabled,
            updated_at=now,
        )
        db.add(row)
    db.commit()
    db.refresh(row)
    return _token_row_to_dict(row)


def unregister_device_token(db: Session, *, fcm_token: str) -> bool:
    deleted = (
        db.query(DevicePushTokenRow)
        .filter(DevicePushTokenRow.fcm_token == fcm_token.strip())
        .delete()
    )
    db.commit()
    return deleted > 0


def update_preferences(
    db: Session,
    *,
    member_email: str,
    fcm_token: str,
    chat_enabled: bool | None = None,
    job_alerts_enabled: bool | None = None,
    application_updates_enabled: bool | None = None,
) -> dict | None:
    email = member_email.strip().lower()
    row = (
        db.query(DevicePushTokenRow)
        .filter(
            DevicePushTokenRow.fcm_token == fcm_token.strip(),
            DevicePushTokenRow.member_email == email,
        )
        .first()
    )
    if row is None:
        return None
    if chat_enabled is not None:
        row.chat_enabled = chat_enabled
    if job_alerts_enabled is not None:
        row.job_alerts_enabled = job_alerts_enabled
    if application_updates_enabled is not None:
        row.application_updates_enabled = application_updates_enabled
    row.updated_at = datetime.now(timezone.utc).replace(tzinfo=None)
    db.commit()
    db.refresh(row)
    return _token_row_to_dict(row)


def _token_row_to_dict(row: DevicePushTokenRow) -> dict:
    return {
        "id": row.id,
        "member_email": row.member_email,
        "member_type": row.member_type,
        "platform": row.platform,
        "chat_enabled": row.chat_enabled,
        "job_alerts_enabled": row.job_alerts_enabled,
        "application_updates_enabled": row.application_updates_enabled,
        "updated_at": row.updated_at.isoformat() if row.updated_at else None,
    }


def tokens_for_emails(
    db: Session,
    emails: list[str],
    *,
    category: str,
) -> list[str]:
    normalized = {email.strip().lower() for email in emails if email.strip()}
    if not normalized:
        return []
    rows = (
        db.query(DevicePushTokenRow)
        .filter(DevicePushTokenRow.member_email.in_(normalized))
        .all()
    )
    tokens: list[str] = []
    for row in rows:
        if category == "chat" and not row.chat_enabled:
            continue
        if category == "job_alerts" and not row.job_alerts_enabled:
            continue
        if category == "application" and not row.application_updates_enabled:
            continue
        if row.fcm_token.strip():
            tokens.append(row.fcm_token.strip())
    return tokens


def tokens_for_company(
    db: Session,
    company_key: str,
    *,
    category: str = "chat",
) -> list[str]:
    from app.qc_models import QcMemberRow
    from app.services.entitlement_service import normalize_brn

    brn = normalize_brn(company_key)
    if not brn:
        return []
    rows = (
        db.query(QcMemberRow)
        .filter(
            QcMemberRow.company_key == brn,
            QcMemberRow.member_type.in_(["corporate", "employer"]),
        )
        .all()
    )
    emails = [row.email for row in rows if row.email]
    return tokens_for_emails(db, emails, category=category)


def seeker_emails_in_radius(
    db: Session,
    *,
    latitude: float,
    longitude: float,
    radius_meters: float,
) -> list[str]:
    from app.qc_models import QcMemberRow

    matched: list[str] = []
    rows = db.query(QcMemberRow).filter(QcMemberRow.member_type == "seeker").all()
    for row in rows:
        raw = (row.seeker_profile_json or "").strip()
        if not raw:
            continue
        try:
            profile = json.loads(raw)
        except json.JSONDecodeError:
            continue
        lat = profile.get("homeLatitude") or profile.get("home_latitude")
        lng = profile.get("homeLongitude") or profile.get("home_longitude")
        if lat is None or lng is None:
            continue
        try:
            distance = _haversine_m(latitude, longitude, float(lat), float(lng))
        except (TypeError, ValueError):
            continue
        if distance <= radius_meters:
            matched.append(row.email)
    return matched
