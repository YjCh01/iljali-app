from sqlalchemy.orm import Session

from app.job_sync_models import JobApplicationRow, JobPostRow
from app.qc_models import QcMemberRow
from app.services.location_usage_log_service import record_usage
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


def push_shift_reminder(
    db: Session,
    *,
    application_id: str,
    kind: str,
    start_at,
) -> dict:
    """근무 시작 1시간 전 리마인더 — 구직자·기업 양쪽에 발송."""
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"seeker_sent": 0, "employer_sent": 0, "skipped": "application_not_found"}

    post_title = app.post_title or "근무"
    seeker_name = app.seeker_name or "지원자"
    time_label = start_at.strftime("%H:%M")
    title = "곧 근무 시작입니다"
    body = f"「{post_title}」 {time_label} 출근 예정입니다."

    result = {"seeker_sent": 0, "employer_sent": 0}

    seeker_tokens = tokens_for_emails(db, [app.seeker_email], category="application")
    if seeker_tokens:
        sent = fcm_service.send_to_tokens(
            seeker_tokens,
            title=title,
            body=body,
            data={
                "type": "shift_reminder",
                "application_id": application_id,
                "kind": kind,
            },
        )
        result["seeker_sent"] = sent["sent"]

    employer_tokens = tokens_for_company(db, app.company_key or "", category="application")
    if employer_tokens:
        sent = fcm_service.send_to_tokens(
            employer_tokens,
            title=title,
            body=f"{seeker_name}님 · {body}",
            data={
                "type": "shift_reminder",
                "application_id": application_id,
                "kind": kind,
            },
        )
        result["employer_sent"] = sent["sent"]

    return result


def push_interview_reminder(db: Session, *, application_id: str, interview_at) -> dict:
    """면접 1시간 전 리마인더 — 구직자·기업 양쪽에 발송."""
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"seeker_sent": 0, "employer_sent": 0, "skipped": "application_not_found"}

    post_title = app.post_title or "채용"
    seeker_name = app.seeker_name or "지원자"
    time_label = interview_at.strftime("%H:%M")
    title = "곧 면접 시작입니다"
    body = f"「{post_title}」 {time_label} 면접 예정입니다."

    result = {"seeker_sent": 0, "employer_sent": 0}

    seeker_tokens = tokens_for_emails(db, [app.seeker_email], category="application")
    if seeker_tokens:
        sent = fcm_service.send_to_tokens(
            seeker_tokens,
            title=title,
            body=body,
            data={
                "type": "interview_reminder",
                "application_id": application_id,
            },
        )
        result["seeker_sent"] = sent["sent"]

    employer_tokens = tokens_for_company(db, app.company_key or "", category="application")
    if employer_tokens:
        sent = fcm_service.send_to_tokens(
            employer_tokens,
            title=title,
            body=f"{seeker_name}님 · {body}",
            data={
                "type": "interview_reminder",
                "application_id": application_id,
            },
        )
        result["employer_sent"] = sent["sent"]

    return result


def push_shuttle_boarding_reminder(
    db: Session, *, application_id: str, pickup_at
) -> dict:
    """셔틀 탑승 30분 전 리마인더 — 구직자에게만 발송."""
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"sent": 0, "skipped": "application_not_found"}

    tokens = tokens_for_emails(db, [app.seeker_email], category="application")
    if not tokens:
        return {"sent": 0, "skipped": "no_tokens"}

    stop_label = app.shuttle_stop_label or "정류장"
    result = fcm_service.send_to_tokens(
        tokens,
        title="탑승 30분 전입니다",
        body=f"{stop_label}에서 {pickup_at.strftime('%H:%M')} 셔틀 탑승 예정입니다.",
        data={
            "type": "shuttle_boarding_reminder",
            "application_id": application_id,
        },
    )
    return {"sent": result["sent"], "failed": result["failed"]}


def push_work_schedule_confirmed(db: Session, *, application_id: str) -> dict:
    """근무예정 합의(양측 확인) 완료 즉시 — 구직자·기업 양쪽에 발송."""
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"seeker_sent": 0, "employer_sent": 0, "skipped": "application_not_found"}

    post_title = app.post_title or "근무"
    seeker_name = app.seeker_name or "지원자"
    title = "근무 일정이 확정되었습니다"
    body = f"「{post_title}」 근무 일정이 확정되었습니다."

    result = {"seeker_sent": 0, "employer_sent": 0}

    seeker_tokens = tokens_for_emails(db, [app.seeker_email], category="application")
    if seeker_tokens:
        sent = fcm_service.send_to_tokens(
            seeker_tokens,
            title=title,
            body=body,
            data={
                "type": "work_schedule_confirmed",
                "application_id": application_id,
            },
        )
        result["seeker_sent"] = sent["sent"]

    employer_tokens = tokens_for_company(db, app.company_key or "", category="application")
    if employer_tokens:
        sent = fcm_service.send_to_tokens(
            employer_tokens,
            title=title,
            body=f"{seeker_name}님 · {body}",
            data={
                "type": "work_schedule_confirmed",
                "application_id": application_id,
            },
        )
        result["employer_sent"] = sent["sent"]

    return result


def push_interview_confirmed(db: Session, *, application_id: str) -> dict:
    """면접 일정 상호 확인 완료 즉시 — 구직자·기업 양쪽에 발송."""
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"seeker_sent": 0, "employer_sent": 0, "skipped": "application_not_found"}

    post_title = app.post_title or "채용"
    seeker_name = app.seeker_name or "지원자"
    title = "면접 일정이 확정되었습니다"
    body = f"「{post_title}」 면접 일정이 확정되었습니다."

    result = {"seeker_sent": 0, "employer_sent": 0}

    seeker_tokens = tokens_for_emails(db, [app.seeker_email], category="application")
    if seeker_tokens:
        sent = fcm_service.send_to_tokens(
            seeker_tokens,
            title=title,
            body=body,
            data={
                "type": "interview_confirmed",
                "application_id": application_id,
            },
        )
        result["seeker_sent"] = sent["sent"]

    employer_tokens = tokens_for_company(db, app.company_key or "", category="application")
    if employer_tokens:
        sent = fcm_service.send_to_tokens(
            employer_tokens,
            title=title,
            body=f"{seeker_name}님 · {body}",
            data={
                "type": "interview_confirmed",
                "application_id": application_id,
            },
        )
        result["employer_sent"] = sent["sent"]

    return result


def push_new_applicant(db: Session, *, application_id: str) -> dict:
    """지원 접수 즉시 기업회원에게 알림 — 지원자 탭을 직접 열어봐야만 알 수 있던 공백을 메움."""
    app = db.get(JobApplicationRow, application_id)
    if app is None:
        return {"sent": 0, "skipped": "application_not_found"}

    tokens = tokens_for_company(db, app.company_key or "", category="application")
    if not tokens:
        return {"sent": 0, "skipped": "no_tokens"}

    post_title = app.post_title or "채용 공고"
    seeker_name = app.seeker_name or "지원자"
    result = fcm_service.send_to_tokens(
        tokens,
        title="새 지원자가 도착했습니다",
        body=f"{seeker_name}님이 「{post_title}」에 지원했습니다.",
        data={
            "type": "new_applicant",
            "application_id": application_id,
            "post_id": app.post_id,
            "post_title": post_title,
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
    representative_lat: float | None = None
    representative_lng: float | None = None
    for target in targets:
        try:
            lat = float(target["latitude"])
            lng = float(target["longitude"])
            radius = float(target.get("radius_meters") or 1000)
        except (KeyError, TypeError, ValueError):
            continue
        if representative_lat is None:
            representative_lat, representative_lng = lat, lng
        for email in seeker_emails_in_radius(
            db, latitude=lat, longitude=lng, radius_meters=radius
        ):
            matched_emails.add(email.strip().lower())

    if targets:
        record_usage(
            db,
            usage_type="push_radius",
            subject_label="기업회원",
            subject_email="",
            acquisition_path="단말 위치(동의, 설정범위)",
            service_description=f"위치기반 PUSH — post_id={post_id}",
            recipient_label=f"구직자 {len(matched_emails)}명(동의자만)",
            latitude=representative_lat,
            longitude=representative_lng,
            detail={
                "post_id": post_id,
                "company_key": company_key,
                "target_zones": len(targets),
                "matched_emails": sorted(matched_emails),
            },
        )

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
