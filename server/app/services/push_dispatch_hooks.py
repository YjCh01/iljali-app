from sqlalchemy.orm import Session

from app.job_sync_models import JobApplicationRow, JobPostRow
from app.qc_models import QcMemberRow
from app.services.push_notification_service import (
    fcm_service,
    seeker_emails_in_radius,
    tokens_for_company,
    tokens_for_emails,
)


def push_chat_message(
    db: Session,
    *,
    application_id: str,
    message: dict,
) -> dict:
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"sent": 0, "skipped": "application_not_found"}

    sender_role = (message.get("sender_role") or "").strip().lower()
    body = (message.get("body") or "").strip()
    if not body:
        return {"sent": 0, "skipped": "empty_body"}

    post_title = app.post_title or "채용 공고"
    company_name = app.company_name or "채용 기업"
    seeker_name = app.seeker_name or "지원자"

    if sender_role in {"seeker", "system"}:
        title = f"{seeker_name} · 채팅"
        preview = body if len(body) <= 80 else f"{body[:80]}…"
        tokens = tokens_for_company(db, app.company_key or "", category="chat")
    else:
        title = f"{company_name} · 채팅"
        preview = body if len(body) <= 80 else f"{body[:80]}…"
        tokens = tokens_for_emails(db, [app.seeker_email], category="chat")

    if not tokens:
        return {"sent": 0, "skipped": "no_tokens"}

    result = fcm_service.send_to_tokens(
        tokens,
        title=title,
        body=preview,
        data={
            "type": "chat_message",
            "application_id": application_id,
            "post_title": post_title,
            "company_name": company_name,
        },
    )
    return {"sent": result["sent"], "failed": result["failed"]}


def _normalize_audience(audience: str | None) -> str:
    value = (audience or "all").strip().lower()
    if value not in {"all", "seeker", "corporate"}:
        return "all"
    return value


def _audience_visible(audience: str, member_type: str | None) -> bool:
    normalized = _normalize_audience(audience)
    if normalized == "all":
        return True
    if not member_type:
        return False
    member = member_type.strip().lower()
    if member in {"seeker", "individual"}:
        return normalized == "seeker"
    if member in {"corporate", "employer"}:
        return normalized == "corporate"
    return False


def push_admin_announcement(db: Session, *, announcement: dict) -> dict:
    if not announcement.get("push_requested", True):
        return {"sent": 0, "skipped": "push_not_requested"}

    audience = announcement.get("audience") or "all"
    title = announcement.get("title") or "일자리 운영 공지"
    body = announcement.get("body") or ""
    preview = body.replace("\n", " ").strip()
    if len(preview) > 100:
        preview = f"{preview[:100]}…"

    rows = db.query(QcMemberRow).all()
    emails: list[str] = []
    for row in rows:
        member_type = row.member_type or "seeker"
        if member_type in {"corporate", "employer"}:
            normalized = "corporate"
        else:
            normalized = "seeker"
        if _audience_visible(audience, normalized):
            emails.append(row.email)

    tokens = tokens_for_emails(db, emails, category="chat")
    if not tokens:
        return {"sent": 0, "skipped": "no_tokens"}

    result = fcm_service.send_to_tokens(
        tokens,
        title=title,
        body=preview or title,
        data={
            "type": "admin_announcement",
            "announcement_id": announcement.get("id") or "",
            "audience": audience,
        },
    )
    return {"sent": result["sent"], "failed": result["failed"]}


def push_recruitment_targets(
    db: Session,
    *,
    post_id: str,
    title: str,
    company_name: str,
    company_key: str,
    targets: list[dict],
) -> dict:
    post = db.get(JobPostRow, post_id)
    resolved_title = title or (post.title if post else "새 채용 공지")
    resolved_company = company_name or (post.company_name if post else "채용 기업")

    matched_emails: set[str] = set()
    for target in targets:
        try:
            lat = float(target["latitude"])
            lng = float(target["longitude"])
            radius = float(target.get("radius_meters") or 1000)
        except (KeyError, TypeError, ValueError):
            continue
        for email in seeker_emails_in_radius(
            db, latitude=lat, longitude=lng, radius_meters=radius
        ):
            matched_emails.add(email.strip().lower())

    tokens = tokens_for_emails(db, list(matched_emails), category="job_alerts")
    if not tokens:
        return {
            "matched_seekers": len(matched_emails),
            "sent": 0,
            "skipped": "no_tokens",
        }

    body = f"{resolved_company} · {resolved_title}"
    result = fcm_service.send_to_tokens(
        tokens,
        title="근처 새 일자리 PUSH",
        body=body,
        data={
            "type": "job_recruitment",
            "post_id": post_id,
            "company_name": resolved_company,
            "company_key": company_key,
            "title": resolved_title,
        },
    )
    return {
        "matched_seekers": len(matched_emails),
        "sent": result["sent"],
        "failed": result["failed"],
    }
