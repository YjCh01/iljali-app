from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware

from app.config import settings
from app.database import (
    Base,
    SessionLocal,
    engine,
    ensure_abuse_flag_schema,
    ensure_admin_announcement_schema,
    ensure_payment_order_schema,
    ensure_qc_member_schema,
    ensure_push_wallet_schema,
)
from app.notification_models import DevicePushTokenRow  # noqa: F401
from app.push_wallet_models import (  # noqa: F401
    CompanyBonusLedgerRow,
    EmployerPushWalletRow,
    PushWalletCreditLotRow,
)
from app.job_sync_models import (  # noqa: F401
    ChatMessageRow,
    JobApplicationRow,
    JobPostRow,
    PaymentOrderRow,
    WorkplaceRow,
)
from app.pilot_models import AppPilotProgramRow, BusLocationTowerSessionRow  # noqa: F401
from app.shuttle_models import (
    CommuteRouteRow,
    SeekerShuttlePreferenceRow,
    ShuttleRouteShareConsentRow,
)
from app.qc_models import (  # noqa: F401
    AdminAuditLogRow,
    ClosedGhostPinRow,
    ClosedGhostRouteRow,
    EventPinRow,
    AdminAnnouncementRow,
    CompanySanctionRow,
    JobPostEntitlementRow,
    MemberSanctionHistoryRow,
    MemberSocialLinkRow,
    QcMemberRow,
)
from app.services.social_auth_service import social_mock_enabled
from app.services.workplace_service import backfill_missing_workplace_ids
from app.routers import (
    addresses,
    admin,
    admin_ops,
    auth,
    chat_sync,
    compliance,
    hiring,
    job_board,
    job_import,
    job_media,
    metrics,
    pilot,
    resume_import,
    shuttle,
    notifications,
    ocr,
    payment_webhook,
    payments,
    push_wallet,
    social_auth,
    sync,
)

Base.metadata.create_all(bind=engine)
ensure_qc_member_schema()
ensure_push_wallet_schema()
ensure_admin_announcement_schema()
ensure_abuse_flag_schema()
ensure_payment_order_schema()

with SessionLocal() as _startup_db:
    backfill_missing_workplace_ids(_startup_db)

app = FastAPI(
    title="Iljari Compliance API",
    description="사업자 검증·연락 entitlement·파트너십 구독",
    version="1.0.0",
)

origins = [
    o.strip()
    for o in settings.cors_origins.split(",")
    if o.strip() and o.strip() != "*"
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"],
)
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts=["*"])

app.include_router(compliance.router)
app.include_router(auth.router)
app.include_router(social_auth.router)
app.include_router(addresses.router)
app.include_router(admin.router)
app.include_router(admin.sub_router)
app.include_router(admin_ops.router)
app.include_router(payments.router)
app.include_router(payment_webhook.router)
app.include_router(ocr.router)
app.include_router(metrics.router)
app.include_router(push_wallet.router)
app.include_router(notifications.router)
app.include_router(job_board.router)
app.include_router(job_import.router)
app.include_router(resume_import.router)
app.include_router(pilot.router)
app.include_router(shuttle.router)
app.include_router(job_media.router)
app.include_router(hiring.router)
app.include_router(chat_sync.router)
app.include_router(sync.router)

_media_dir = Path(settings.job_media_dir)
_media_dir.mkdir(parents=True, exist_ok=True)
app.mount(
    "/media/job-posts",
    StaticFiles(directory=str(_media_dir)),
    name="job-post-media",
)


@app.get("/")
def api_root():
    return {
        "service": "iljari-api",
        "status": "ok",
        "app": "https://iljari.app/",
        "corporate": "https://iljari.app/corporate/",
        "admin": "https://iljari.app/admin/",
        "health": "/health",
        "note": "브라우저 앱은 iljari.app — 이 주소는 API 전용",
    }


@app.get("/health")
def health():
    return {
        "status": "ok",
        "nts_configured": bool(settings.nts_api_key),
        "toss_configured": bool(settings.toss_secret_key),
        "free_exposure_promo": settings.is_free_exposure_promo,
        "toss_client_configured": bool(settings.toss_client_key),
        "database_url": settings.database_url.split("://", 1)[0],
        "juso_configured": bool(settings.juso_confm_key),
        "kakao_geocode_configured": bool(settings.kakao_rest_api_key),
        "admin_ops_configured": bool(settings.admin_api_key),
        "qc_payment_mode": settings.qc_payment_mode,
        "auth_configured": bool(settings.auth_token_secret or settings.admin_api_key),
        "sms_provider": settings.sms_provider,
        "social_auth_mock": social_mock_enabled(),
    }
