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
}


def ensure_qc_member_schema() -> None:
    """Rolling deploy — add qc_members / job_posts columns if missing."""
    if settings.database_url.startswith("sqlite"):
        _ensure_sqlite_columns("qc_members", _QC_MEMBER_COLUMNS_SQLITE)
        _ensure_sqlite_columns("job_posts", _JOB_POST_COLUMNS_SQLITE)
    else:
        _ensure_postgres_columns(_QC_MEMBER_COLUMNS_POSTGRES)
        _ensure_postgres_columns(_JOB_POST_COLUMNS_POSTGRES)


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
