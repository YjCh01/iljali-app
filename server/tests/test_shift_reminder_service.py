from datetime import datetime, timedelta
from unittest.mock import patch

from app.database import Base, SessionLocal, engine
from app.job_sync_models import JobApplicationRow
from app.main import app  # noqa: F401 — 임포트 시점에 job_applications 컬럼 마이그레이션 실행
from app.services.auth_token_service import issue_token
from app.services.shift_reminder_service import (
    REMINDER_LEAD,
    SHUTTLE_REMINDER_LEAD,
    run_reminder_sweep,
)

Base.metadata.create_all(bind=engine)


def _seeker_headers(seeker_email: str) -> dict[str, str]:
    token = issue_token({"sub": seeker_email, "member_type": "seeker"})
    return {"Authorization": f"Bearer {token}"}


def _make_application(db, key: str, **overrides) -> JobApplicationRow:
    defaults = dict(
        id=f"app_reminder_{key}",
        post_id="post_reminder_1",
        post_title="테스트 공고",
        company_name="테스트 기업",
        company_key="7020009999",
        seeker_email="seeker-reminder@qc.iljari.co.kr",
        seeker_name="지원자",
        status="scheduled",
        work_schedule="09:00-18:00",
        work_date="",
        interview_at="",
        shuttle_pickup_time="",
        shuttle_shift_date="",
        work_reminder_sent_at=None,
        interview_reminder_sent_at=None,
        shuttle_reminder_sent_at=None,
    )
    defaults.update(overrides)
    row = JobApplicationRow(**defaults)
    db.add(row)
    db.commit()
    return row


def setup_function(_fn):
    db = SessionLocal()
    try:
        db.query(JobApplicationRow).filter(
            JobApplicationRow.id.like("app_reminder_%")
        ).delete(synchronize_session=False)
        db.commit()
    finally:
        db.close()


def test_sends_work_reminder_one_hour_before():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        work_dt = now + REMINDER_LEAD - timedelta(minutes=5)
        _make_application(
            db,
            "work1",
            work_date=work_dt.date().isoformat(),
            work_schedule=f"{work_dt.strftime('%H:%M')}-18:00",
        )
        result = run_reminder_sweep(db)
        assert result["work_reminders_sent"] == 1

        row = db.get(JobApplicationRow, "app_reminder_work1")
        assert row.work_reminder_sent_at is not None
    finally:
        db.close()


def test_does_not_resend_work_reminder():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        work_dt = now + REMINDER_LEAD - timedelta(minutes=5)
        _make_application(
            db,
            "worksent",
            work_date=work_dt.date().isoformat(),
            work_schedule=f"{work_dt.strftime('%H:%M')}-18:00",
            work_reminder_sent_at=now - timedelta(minutes=1),
        )
        with patch(
            "app.services.shift_reminder_service.push_shift_reminder"
        ) as mock_push:
            run_reminder_sweep(db)
        assert mock_push.call_count == 0
    finally:
        db.close()


def test_skips_work_reminder_with_unparseable_schedule():
    db = SessionLocal()
    try:
        work_dt = datetime.utcnow() + timedelta(minutes=30)
        _make_application(
            db,
            "badschedule",
            work_date=work_dt.date().isoformat(),
            work_schedule="협의",
        )
        run_reminder_sweep(db)
        row = db.get(JobApplicationRow, "app_reminder_badschedule")
        assert row.work_reminder_sent_at is None
    finally:
        db.close()


def test_skips_work_reminder_already_past_start_time():
    db = SessionLocal()
    try:
        work_dt = datetime.utcnow() - timedelta(hours=2)
        _make_application(
            db,
            "past",
            work_date=work_dt.date().isoformat(),
            work_schedule=f"{work_dt.strftime('%H:%M')}-18:00",
        )
        run_reminder_sweep(db)
        row = db.get(JobApplicationRow, "app_reminder_past")
        assert row.work_reminder_sent_at is None
    finally:
        db.close()


def test_sends_interview_reminder_one_hour_before():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        interview_at = now + REMINDER_LEAD - timedelta(minutes=5)
        _make_application(
            db,
            "interview1",
            interview_at=interview_at.isoformat(),
        )
        result = run_reminder_sweep(db)
        assert result["interview_reminders_sent"] == 1

        row = db.get(JobApplicationRow, "app_reminder_interview1")
        assert row.interview_reminder_sent_at is not None
    finally:
        db.close()


def test_skips_interview_reminder_when_not_yet_confirmed():
    db = SessionLocal()
    try:
        _make_application(db, "nointerview", interview_at="")
        run_reminder_sweep(db)
        row = db.get(JobApplicationRow, "app_reminder_nointerview")
        assert row.interview_reminder_sent_at is None
    finally:
        db.close()


def test_sends_shuttle_boarding_reminder_thirty_minutes_before():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        pickup_at = now + SHUTTLE_REMINDER_LEAD - timedelta(minutes=5)
        _make_application(
            db,
            "shuttle1",
            shuttle_shift_date=pickup_at.date().isoformat(),
            shuttle_pickup_time=pickup_at.strftime("%H:%M"),
            shuttle_stop_label="정문 정류장",
        )
        result = run_reminder_sweep(db)
        assert result["shuttle_reminders_sent"] == 1

        row = db.get(JobApplicationRow, "app_reminder_shuttle1")
        assert row.shuttle_reminder_sent_at is not None
    finally:
        db.close()


def test_does_not_send_shuttle_reminder_outside_window():
    db = SessionLocal()
    try:
        now = datetime.utcnow()
        pickup_at = now + timedelta(hours=3)
        _make_application(
            db,
            "shuttlefar",
            shuttle_shift_date=pickup_at.date().isoformat(),
            shuttle_pickup_time=pickup_at.strftime("%H:%M"),
        )
        run_reminder_sweep(db)
        row = db.get(JobApplicationRow, "app_reminder_shuttlefar")
        assert row.shuttle_reminder_sent_at is None
    finally:
        db.close()


def test_changing_work_date_resets_work_reminder_flag_via_update_endpoint():
    from fastapi.testclient import TestClient

    from app.main import app

    client = TestClient(app)
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_reminder_reset",
            "seeker_email": "seeker-reminder-reset@qc.iljari.co.kr",
            "status": "scheduled",
            "work_date": "2026-08-01",
        },
        headers=_seeker_headers("seeker-reminder-reset@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text
    application_id = resp.json()["id"]

    db = SessionLocal()
    try:
        row = db.get(JobApplicationRow, application_id)
        row.work_reminder_sent_at = datetime.utcnow()
        db.commit()
    finally:
        db.close()

    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_reminder_reset",
            "seeker_email": "seeker-reminder-reset@qc.iljari.co.kr",
            "status": "scheduled",
            "work_date": "2026-08-02",
        },
        headers=_seeker_headers("seeker-reminder-reset@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text

    db = SessionLocal()
    try:
        row = db.get(JobApplicationRow, application_id)
        assert row.work_date == "2026-08-02"
        assert row.work_reminder_sent_at is None
    finally:
        db.close()


def test_changing_interview_at_resets_interview_reminder_flag_via_update_endpoint():
    from fastapi.testclient import TestClient

    from app.main import app

    client = TestClient(app)
    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_interview_reset",
            "seeker_email": "seeker-interview-reset@qc.iljari.co.kr",
            "status": "scheduled",
            "interview_at": "2026-08-01T10:00:00",
        },
        headers=_seeker_headers("seeker-interview-reset@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text
    application_id = resp.json()["id"]

    db = SessionLocal()
    try:
        row = db.get(JobApplicationRow, application_id)
        row.interview_reminder_sent_at = datetime.utcnow()
        db.commit()
    finally:
        db.close()

    resp = client.post(
        "/v1/hiring/applications",
        json={
            "post_id": "post_interview_reset",
            "seeker_email": "seeker-interview-reset@qc.iljari.co.kr",
            "status": "scheduled",
            "interview_at": "2026-08-02T11:00:00",
        },
        headers=_seeker_headers("seeker-interview-reset@qc.iljari.co.kr"),
    )
    assert resp.status_code == 200, resp.text

    db = SessionLocal()
    try:
        row = db.get(JobApplicationRow, application_id)
        assert row.interview_at == "2026-08-02T11:00:00"
        assert row.interview_reminder_sent_at is None
    finally:
        db.close()
