from sqlalchemy import create_engine, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings

connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
engine = create_engine(settings.database_url, connect_args=connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


_QC_MEMBER_COLUMNS_SQLITE = {
    "phone": "ALTER TABLE qc_members ADD COLUMN phone VARCHAR(32) DEFAULT ''",
    "org_role": "ALTER TABLE qc_members ADD COLUMN org_role VARCHAR(32) DEFAULT ''",
    "branch_name": "ALTER TABLE qc_members ADD COLUMN branch_name VARCHAR(200) DEFAULT ''",
    "department": "ALTER TABLE qc_members ADD COLUMN department VARCHAR(100) DEFAULT ''",
    "contact_person_name": "ALTER TABLE qc_members ADD COLUMN contact_person_name VARCHAR(100) DEFAULT ''",
    "handler_code": "ALTER TABLE qc_members ADD COLUMN handler_code VARCHAR(32) DEFAULT ''",
    "sanction_tier": "ALTER TABLE qc_members ADD COLUMN sanction_tier VARCHAR(16) DEFAULT ''",
    "warning_count": "ALTER TABLE qc_members ADD COLUMN warning_count INTEGER DEFAULT 0",
    "sanction_restrictions_json": "ALTER TABLE qc_members ADD COLUMN sanction_restrictions_json TEXT DEFAULT '{}'",
    "appeal_until": "ALTER TABLE qc_members ADD COLUMN appeal_until DATETIME",
    "admin_review_required": "ALTER TABLE qc_members ADD COLUMN admin_review_required BOOLEAN DEFAULT 0",
    "password_hash": "ALTER TABLE qc_members ADD COLUMN password_hash VARCHAR(256) DEFAULT ''",
    "phone_verified_at": "ALTER TABLE qc_members ADD COLUMN phone_verified_at DATETIME",
    "seeker_profile_json": "ALTER TABLE qc_members ADD COLUMN seeker_profile_json TEXT DEFAULT '{}'",
    "no_show_count": "ALTER TABLE qc_members ADD COLUMN no_show_count INTEGER DEFAULT 0",
}

_QC_MEMBER_COLUMNS_POSTGRES = {
    "phone": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS phone VARCHAR(32) DEFAULT ''",
    "org_role": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS org_role VARCHAR(32) DEFAULT ''",
    "branch_name": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS branch_name VARCHAR(200) DEFAULT ''",
    "department": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS department VARCHAR(100) DEFAULT ''",
    "contact_person_name": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS contact_person_name VARCHAR(100) DEFAULT ''",
    "handler_code": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS handler_code VARCHAR(32) DEFAULT ''",
    "sanction_tier": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS sanction_tier VARCHAR(16) DEFAULT ''",
    "warning_count": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS warning_count INTEGER DEFAULT 0",
    "sanction_restrictions_json": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS sanction_restrictions_json TEXT DEFAULT '{}'",
    "appeal_until": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS appeal_until TIMESTAMP",
    "admin_review_required": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS admin_review_required BOOLEAN DEFAULT FALSE",
    "password_hash": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS password_hash VARCHAR(256) DEFAULT ''",
    "phone_verified_at": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS phone_verified_at TIMESTAMP",
    "seeker_profile_json": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS seeker_profile_json TEXT DEFAULT '{}'",
    "no_show_count": "ALTER TABLE qc_members ADD COLUMN IF NOT EXISTS no_show_count INTEGER DEFAULT 0",
}

_JOB_POST_COLUMNS_SQLITE = {
    "posted_by_email": "ALTER TABLE job_posts ADD COLUMN posted_by_email VARCHAR(200) DEFAULT ''",
    "posted_by_name": "ALTER TABLE job_posts ADD COLUMN posted_by_name VARCHAR(100) DEFAULT ''",
    "view_count": "ALTER TABLE job_posts ADD COLUMN view_count INTEGER DEFAULT 0",
    "map_impression_count": "ALTER TABLE job_posts ADD COLUMN map_impression_count INTEGER DEFAULT 0",
    "job_description": "ALTER TABLE job_posts ADD COLUMN job_description TEXT DEFAULT ''",
    "description_body_json": "ALTER TABLE job_posts ADD COLUMN description_body_json TEXT DEFAULT '{}'",
    "workplace_latitude": "ALTER TABLE job_posts ADD COLUMN workplace_latitude REAL",
    "workplace_longitude": "ALTER TABLE job_posts ADD COLUMN workplace_longitude REAL",
    "workplace_id": "ALTER TABLE job_posts ADD COLUMN workplace_id VARCHAR(32)",
    "required_credential_ids_json": (
        "ALTER TABLE job_posts ADD COLUMN required_credential_ids_json TEXT DEFAULT '[]'"
    ),
    "notification_settings_json": "ALTER TABLE job_posts ADD COLUMN notification_settings_json TEXT DEFAULT '{}'",
}

_JOB_POST_COLUMNS_POSTGRES = {
    "posted_by_email": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS posted_by_email VARCHAR(200) DEFAULT ''",
    "posted_by_name": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS posted_by_name VARCHAR(100) DEFAULT ''",
    "view_count": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS view_count INTEGER DEFAULT 0",
    "map_impression_count": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS map_impression_count INTEGER DEFAULT 0",
    "job_description": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS job_description TEXT DEFAULT ''",
    "description_body_json": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS description_body_json TEXT DEFAULT '{}'",
    "workplace_latitude": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS workplace_latitude DOUBLE PRECISION",
    "workplace_longitude": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS workplace_longitude DOUBLE PRECISION",
    "workplace_id": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS workplace_id VARCHAR(32)",
    "required_credential_ids_json": (
        "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS "
        "required_credential_ids_json TEXT DEFAULT '[]'"
    ),
    "notification_settings_json": "ALTER TABLE job_posts ADD COLUMN IF NOT EXISTS notification_settings_json TEXT DEFAULT '{}'",
}

_JOB_APPLICATION_COLUMNS_SQLITE = {
    "commute_route_id": "ALTER TABLE job_applications ADD COLUMN commute_route_id VARCHAR(64) DEFAULT ''",
    "commute_route_name": "ALTER TABLE job_applications ADD COLUMN commute_route_name VARCHAR(200) DEFAULT ''",
    "shuttle_stop_id": "ALTER TABLE job_applications ADD COLUMN shuttle_stop_id VARCHAR(64) DEFAULT ''",
    "shuttle_stop_label": "ALTER TABLE job_applications ADD COLUMN shuttle_stop_label VARCHAR(200) DEFAULT ''",
    "shuttle_pickup_time": "ALTER TABLE job_applications ADD COLUMN shuttle_pickup_time VARCHAR(32) DEFAULT ''",
    "shuttle_shift_date": "ALTER TABLE job_applications ADD COLUMN shuttle_shift_date VARCHAR(10) DEFAULT ''",
    "required_credential_ids_json": (
        "ALTER TABLE job_applications ADD COLUMN "
        "required_credential_ids_json TEXT DEFAULT '[]'"
    ),
    "held_credential_ids_json": (
        "ALTER TABLE job_applications ADD COLUMN "
        "held_credential_ids_json TEXT DEFAULT '[]'"
    ),
    "work_date": "ALTER TABLE job_applications ADD COLUMN work_date VARCHAR(10) DEFAULT ''",
    "work_reminder_sent_at": (
        "ALTER TABLE job_applications ADD COLUMN work_reminder_sent_at DATETIME"
    ),
    "interview_at": "ALTER TABLE job_applications ADD COLUMN interview_at VARCHAR(32) DEFAULT ''",
    "interview_reminder_sent_at": (
        "ALTER TABLE job_applications ADD COLUMN interview_reminder_sent_at DATETIME"
    ),
    "shuttle_reminder_sent_at": (
        "ALTER TABLE job_applications ADD COLUMN shuttle_reminder_sent_at DATETIME"
    ),
}

_JOB_APPLICATION_COLUMNS_POSTGRES = {
    "commute_route_id": "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS commute_route_id VARCHAR(64) DEFAULT ''",
    "commute_route_name": "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS commute_route_name VARCHAR(200) DEFAULT ''",
    "shuttle_stop_id": "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS shuttle_stop_id VARCHAR(64) DEFAULT ''",
    "shuttle_stop_label": "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS shuttle_stop_label VARCHAR(200) DEFAULT ''",
    "shuttle_pickup_time": "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS shuttle_pickup_time VARCHAR(32) DEFAULT ''",
    "shuttle_shift_date": "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS shuttle_shift_date VARCHAR(10) DEFAULT ''",
    "required_credential_ids_json": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "required_credential_ids_json TEXT DEFAULT '[]'"
    ),
    "held_credential_ids_json": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "held_credential_ids_json TEXT DEFAULT '[]'"
    ),
    "work_date": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "work_date VARCHAR(10) DEFAULT ''"
    ),
    "work_reminder_sent_at": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "work_reminder_sent_at TIMESTAMP"
    ),
    "interview_at": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "interview_at VARCHAR(32) DEFAULT ''"
    ),
    "interview_reminder_sent_at": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "interview_reminder_sent_at TIMESTAMP"
    ),
    "shuttle_reminder_sent_at": (
        "ALTER TABLE job_applications ADD COLUMN IF NOT EXISTS "
        "shuttle_reminder_sent_at TIMESTAMP"
    ),
}

_PILOT_PROGRAM_COLUMNS_SQLITE = {
    "company_key": "ALTER TABLE app_pilot_programs ADD COLUMN company_key VARCHAR(10) DEFAULT ''",
    "company_name": "ALTER TABLE app_pilot_programs ADD COLUMN company_name VARCHAR(200) DEFAULT ''",
    "route_id": "ALTER TABLE app_pilot_programs ADD COLUMN route_id VARCHAR(64) DEFAULT ''",
    "route_name": "ALTER TABLE app_pilot_programs ADD COLUMN route_name VARCHAR(200) DEFAULT ''",
    "work_start_time": "ALTER TABLE app_pilot_programs ADD COLUMN work_start_time VARCHAR(5) DEFAULT ''",
}

_PILOT_PROGRAM_COLUMNS_POSTGRES = {
    "company_key": "ALTER TABLE app_pilot_programs ADD COLUMN IF NOT EXISTS company_key VARCHAR(10) DEFAULT ''",
    "company_name": "ALTER TABLE app_pilot_programs ADD COLUMN IF NOT EXISTS company_name VARCHAR(200) DEFAULT ''",
    "route_id": "ALTER TABLE app_pilot_programs ADD COLUMN IF NOT EXISTS route_id VARCHAR(64) DEFAULT ''",
    "route_name": "ALTER TABLE app_pilot_programs ADD COLUMN IF NOT EXISTS route_name VARCHAR(200) DEFAULT ''",
    "work_start_time": "ALTER TABLE app_pilot_programs ADD COLUMN IF NOT EXISTS work_start_time VARCHAR(5) DEFAULT ''",
}

_PILOT_SESSION_COLUMNS_SQLITE = {
    "work_start_time": "ALTER TABLE bus_location_tower_sessions ADD COLUMN work_start_time VARCHAR(5) DEFAULT ''",
    "arrived_at_workplace": "ALTER TABLE bus_location_tower_sessions ADD COLUMN arrived_at_workplace BOOLEAN DEFAULT 0",
}

_PILOT_SESSION_COLUMNS_POSTGRES = {
    "work_start_time": "ALTER TABLE bus_location_tower_sessions ADD COLUMN IF NOT EXISTS work_start_time VARCHAR(5) DEFAULT ''",
    "arrived_at_workplace": "ALTER TABLE bus_location_tower_sessions ADD COLUMN IF NOT EXISTS arrived_at_workplace BOOLEAN DEFAULT FALSE",
}


def ensure_qc_member_schema() -> None:
    """Rolling deploy — add qc_members / job_posts columns if missing."""
    if settings.database_url.startswith("sqlite"):
        _ensure_sqlite_columns("qc_members", _QC_MEMBER_COLUMNS_SQLITE)
        _ensure_sqlite_columns("job_posts", _JOB_POST_COLUMNS_SQLITE)
        _ensure_sqlite_columns("job_applications", _JOB_APPLICATION_COLUMNS_SQLITE)
        _ensure_sqlite_columns("app_pilot_programs", _PILOT_PROGRAM_COLUMNS_SQLITE)
        _ensure_sqlite_columns("bus_location_tower_sessions", _PILOT_SESSION_COLUMNS_SQLITE)
    else:
        _ensure_postgres_columns(_QC_MEMBER_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_JOB_POST_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_JOB_APPLICATION_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_PILOT_PROGRAM_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_PILOT_SESSION_COLUMNS_POSTGRES)


_PUSH_WALLET_COLUMNS_SQLITE = {
    "push_ticket_credits": (
        "ALTER TABLE employer_push_wallets ADD COLUMN push_ticket_credits INTEGER DEFAULT 0"
    ),
    "exposure_push_bundle_credits": (
        "ALTER TABLE employer_push_wallets ADD COLUMN "
        "exposure_push_bundle_credits INTEGER DEFAULT 0"
    ),
}

_PUSH_WALLET_COLUMNS_POSTGRES = {
    "push_ticket_credits": (
        "ALTER TABLE employer_push_wallets ADD COLUMN IF NOT EXISTS "
        "push_ticket_credits INTEGER DEFAULT 0"
    ),
    "exposure_push_bundle_credits": (
        "ALTER TABLE employer_push_wallets ADD COLUMN IF NOT EXISTS "
        "exposure_push_bundle_credits INTEGER DEFAULT 0"
    ),
}


_PUSH_WALLET_CREDIT_LOT_COLUMNS_SQLITE = {
    "remaining": "ALTER TABLE push_wallet_credit_lots ADD COLUMN remaining INTEGER",
}

_PUSH_WALLET_CREDIT_LOT_COLUMNS_POSTGRES = {
    "remaining": (
        "ALTER TABLE push_wallet_credit_lots ADD COLUMN IF NOT EXISTS "
        "remaining INTEGER"
    ),
}


def ensure_push_wallet_schema() -> None:
    if settings.database_url.startswith("sqlite"):
        _ensure_sqlite_columns("employer_push_wallets", _PUSH_WALLET_COLUMNS_SQLITE)
        _ensure_sqlite_columns(
            "company_bonus_ledger", _COMPANY_BONUS_LEDGER_COLUMNS_SQLITE
        )
        _ensure_sqlite_columns(
            "push_wallet_credit_lots", _PUSH_WALLET_CREDIT_LOT_COLUMNS_SQLITE
        )
        with engine.begin() as conn:
            conn.execute(
                text(
                    "UPDATE push_wallet_credit_lots SET remaining = count "
                    "WHERE remaining IS NULL"
                )
            )
    else:
        _ensure_postgres_columns(_PUSH_WALLET_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_COMPANY_BONUS_LEDGER_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_PUSH_WALLET_CREDIT_LOT_COLUMNS_POSTGRES)
        with engine.begin() as conn:
            conn.execute(
                text(
                    "UPDATE push_wallet_credit_lots SET remaining = count "
                    "WHERE remaining IS NULL"
                )
            )


_COMPANY_BONUS_LEDGER_COLUMNS_SQLITE = {
    "verification_bonus_claimed": (
        "ALTER TABLE company_bonus_ledger ADD COLUMN "
        "verification_bonus_claimed BOOLEAN DEFAULT 0"
    ),
    "verification_bonus_claimed_at": (
        "ALTER TABLE company_bonus_ledger ADD COLUMN "
        "verification_bonus_claimed_at DATETIME"
    ),
}

_COMPANY_BONUS_LEDGER_COLUMNS_POSTGRES = {
    "verification_bonus_claimed": (
        "ALTER TABLE company_bonus_ledger ADD COLUMN IF NOT EXISTS "
        "verification_bonus_claimed BOOLEAN DEFAULT FALSE"
    ),
    "verification_bonus_claimed_at": (
        "ALTER TABLE company_bonus_ledger ADD COLUMN IF NOT EXISTS "
        "verification_bonus_claimed_at TIMESTAMP"
    ),
}


_PAYMENT_ORDER_COLUMNS_SQLITE = {
    "credit_type": "ALTER TABLE payment_orders ADD COLUMN credit_type VARCHAR(32)",
    "credit_count": "ALTER TABLE payment_orders ADD COLUMN credit_count INTEGER",
    "credit_location_slots": (
        "ALTER TABLE payment_orders ADD COLUMN credit_location_slots INTEGER"
    ),
    "credit_granted": (
        "ALTER TABLE payment_orders ADD COLUMN credit_granted BOOLEAN DEFAULT 0"
    ),
    "refunded_at": "ALTER TABLE payment_orders ADD COLUMN refunded_at DATETIME",
}

_PAYMENT_ORDER_COLUMNS_POSTGRES = {
    "credit_type": (
        "ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS credit_type VARCHAR(32)"
    ),
    "credit_count": (
        "ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS credit_count INTEGER"
    ),
    "credit_location_slots": (
        "ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS "
        "credit_location_slots INTEGER"
    ),
    "credit_granted": (
        "ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS "
        "credit_granted BOOLEAN DEFAULT FALSE"
    ),
    "refunded_at": (
        "ALTER TABLE payment_orders ADD COLUMN IF NOT EXISTS refunded_at TIMESTAMP"
    ),
}


def ensure_payment_order_schema() -> None:
    if settings.database_url.startswith("sqlite"):
        _ensure_sqlite_columns("payment_orders", _PAYMENT_ORDER_COLUMNS_SQLITE)
    else:
        _ensure_postgres_columns(_PAYMENT_ORDER_COLUMNS_POSTGRES)


_ADMIN_ANNOUNCEMENT_COLUMNS_SQLITE = {
    "audience": (
        "ALTER TABLE admin_announcements ADD COLUMN audience VARCHAR(16) DEFAULT 'all'"
    ),
}

_ADMIN_ANNOUNCEMENT_COLUMNS_POSTGRES = {
    "audience": (
        "ALTER TABLE admin_announcements ADD COLUMN IF NOT EXISTS "
        "audience VARCHAR(16) DEFAULT 'all'"
    ),
}


def ensure_admin_announcement_schema() -> None:
    if settings.database_url.startswith("sqlite"):
        _ensure_sqlite_columns(
            "admin_announcements", _ADMIN_ANNOUNCEMENT_COLUMNS_SQLITE
        )
    else:
        _ensure_postgres_columns(_ADMIN_ANNOUNCEMENT_COLUMNS_POSTGRES)


_ABUSE_FLAG_COLUMNS_SQLITE = {
    "post_id": "ALTER TABLE abuse_flags ADD COLUMN post_id VARCHAR(64)",
    "post_title": "ALTER TABLE abuse_flags ADD COLUMN post_title VARCHAR(200)",
    "company_name": "ALTER TABLE abuse_flags ADD COLUMN company_name VARCHAR(200)",
    "head_office_address": "ALTER TABLE abuse_flags ADD COLUMN head_office_address TEXT",
    "workplace_address": "ALTER TABLE abuse_flags ADD COLUMN workplace_address TEXT",
    "distance_meters": "ALTER TABLE abuse_flags ADD COLUMN distance_meters INTEGER",
    "review_status": "ALTER TABLE abuse_flags ADD COLUMN review_status VARCHAR(32)",
    "resolved_action": "ALTER TABLE abuse_flags ADD COLUMN resolved_action VARCHAR(64)",
    "resolved_at": "ALTER TABLE abuse_flags ADD COLUMN resolved_at DATETIME",
}

_ABUSE_FLAG_COLUMNS_POSTGRES = {
    "post_id": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS post_id VARCHAR(64)",
    "post_title": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS post_title VARCHAR(200)",
    "company_name": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS company_name VARCHAR(200)",
    "head_office_address": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS head_office_address TEXT",
    "workplace_address": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS workplace_address TEXT",
    "distance_meters": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS distance_meters INTEGER",
    "review_status": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS review_status VARCHAR(32)",
    "resolved_action": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS resolved_action VARCHAR(64)",
    "resolved_at": "ALTER TABLE abuse_flags ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMP",
}


def ensure_abuse_flag_schema() -> None:
    if settings.database_url.startswith("sqlite"):
        _ensure_sqlite_columns("abuse_flags", _ABUSE_FLAG_COLUMNS_SQLITE)
    else:
        _ensure_postgres_columns(_ABUSE_FLAG_COLUMNS_POSTGRES)


def _ensure_sqlite_columns(table: str, alters: dict[str, str]) -> None:
    with engine.begin() as conn:
        rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
        if not rows:
            return
        existing = {row[1] for row in rows}
        for col, ddl in alters.items():
            if col not in existing:
                conn.execute(text(ddl))


def _ensure_postgres_columns(alters: dict[str, str]) -> None:
    with engine.begin() as conn:
        for ddl in alters.values():
            conn.execute(text(ddl))


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
