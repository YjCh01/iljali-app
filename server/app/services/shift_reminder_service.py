"""근무·면접·셔틀 탑승 — 확정 일정 1시간(셔틀은 30분) 전 리마인더 스윕.

문자 대신 채팅/푸시로 면접·근무 일정을 통보하는 채용 관행을 대체하기 위함.
APScheduler로 주기 실행(server/app/main.py) — 각 애플리케이션은 각 리마인더를
최대 1회만 받는다(*_reminder_sent_at으로 중복 방지).
"""

from __future__ import annotations

import logging
from datetime import date, datetime, timedelta, timezone

from sqlalchemy.orm import Session

from app.job_sync_models import JobApplicationRow
from app.services.push_dispatch_hooks import (
    push_interview_reminder,
    push_shift_reminder,
    push_shuttle_boarding_reminder,
)
from app.services.work_schedule_time import combine_date_and_clock, work_start_at

logger = logging.getLogger(__name__)

REMINDER_LEAD = timedelta(hours=1)
SHUTTLE_REMINDER_LEAD = timedelta(minutes=30)


def _now() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def _due(target: datetime, now: datetime, lead: timedelta) -> bool:
    remaining = target - now
    return timedelta(0) < remaining <= lead


def run_reminder_sweep(db: Session) -> dict:
    now = _now()
    result = {
        "work_reminders_sent": 0,
        "interview_reminders_sent": 0,
        "shuttle_reminders_sent": 0,
    }

    candidates = (
        db.query(JobApplicationRow)
        .filter(JobApplicationRow.status == "scheduled")
        .all()
    )

    for row in candidates:
        if _maybe_send_work_reminder(db, row, now):
            result["work_reminders_sent"] += 1
        if _maybe_send_interview_reminder(db, row, now):
            result["interview_reminders_sent"] += 1
        if _maybe_send_shuttle_reminder(db, row, now):
            result["shuttle_reminders_sent"] += 1

    db.commit()
    return result


def _maybe_send_work_reminder(db: Session, row: JobApplicationRow, now: datetime) -> bool:
    if row.work_reminder_sent_at is not None:
        return False
    if not row.work_date:
        return False
    try:
        work_date = date.fromisoformat(row.work_date)
    except ValueError:
        return False
    start_at = work_start_at(work_date, row.work_schedule)
    if start_at is None or not _due(start_at, now, REMINDER_LEAD):
        return False

    try:
        push_shift_reminder(
            db,
            application_id=row.id,
            kind="hour_before",
            start_at=start_at,
        )
    except Exception:  # noqa: BLE001 — 리마인더 발송 실패가 스윕 전체를 막으면 안 됨
        logger.exception("work-start shift reminder failed for %s", row.id)
    row.work_reminder_sent_at = now
    return True


def _maybe_send_interview_reminder(
    db: Session, row: JobApplicationRow, now: datetime
) -> bool:
    if row.interview_reminder_sent_at is not None:
        return False
    if not row.interview_at:
        return False
    interview_at = datetime.fromisoformat(row.interview_at)
    if not _due(interview_at, now, REMINDER_LEAD):
        return False

    try:
        push_interview_reminder(
            db, application_id=row.id, interview_at=interview_at
        )
    except Exception:  # noqa: BLE001
        logger.exception("interview reminder failed for %s", row.id)
    row.interview_reminder_sent_at = now
    return True


def _maybe_send_shuttle_reminder(
    db: Session, row: JobApplicationRow, now: datetime
) -> bool:
    if row.shuttle_reminder_sent_at is not None:
        return False
    if not row.shuttle_shift_date or not row.shuttle_pickup_time:
        return False
    try:
        shift_date = date.fromisoformat(row.shuttle_shift_date)
    except ValueError:
        return False
    pickup_at = combine_date_and_clock(shift_date, row.shuttle_pickup_time)
    if pickup_at is None or not _due(pickup_at, now, SHUTTLE_REMINDER_LEAD):
        return False

    try:
        push_shuttle_boarding_reminder(
            db, application_id=row.id, pickup_at=pickup_at
        )
    except Exception:  # noqa: BLE001
        logger.exception("shuttle boarding reminder failed for %s", row.id)
    row.shuttle_reminder_sent_at = now
    return True
