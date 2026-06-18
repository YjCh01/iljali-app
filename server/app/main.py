from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import Base, engine
from app.insurance_auth_models import (  # noqa: F401
    InsuranceAuthSession,
    MonthlyReemployment,
)
from app.push_wallet_models import (  # noqa: F401
    CompanyBonusLedgerRow,
    EmployerPushWalletRow,
)
from app.job_sync_models import (  # noqa: F401
    ChatMessageRow,
    JobApplicationRow,
    JobPostRow,
    PaymentOrderRow,
)
from app.permanent_commission_models import (  # noqa: F401
    InsuranceVerificationLog,
    MonthlyCommission,
    PermanentEmployment,
)
from app.jobs.scheduler import start_reverify_scheduler, stop_reverify_scheduler
from app.routers import (
    addresses,
    admin,
    chat_sync,
    compliance,
    hiring,
    insurance_auth,
    job_board,
    job_import,
    metrics,
    ocr,
    notifications,
    payment_webhook,
    payments,
    permanent_commission,
    push_wallet,
)

Base.metadata.create_all(bind=engine)

@asynccontextmanager
async def lifespan(_app: FastAPI):
    start_reverify_scheduler()
    yield
    await stop_reverify_scheduler()


app = FastAPI(
    title="Iljari Compliance API",
    description="사업자 검증·연락 entitlement·파트너십 구독",
    version="1.0.0",
    lifespan=lifespan,
)

origins = [o.strip() for o in settings.cors_origins.split(",") if o.strip()]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins if origins != ["*"] else ["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(compliance.router)
app.include_router(addresses.router)
app.include_router(admin.router)
app.include_router(admin.sub_router)
app.include_router(payments.router)
app.include_router(payment_webhook.router)
app.include_router(ocr.router)
app.include_router(metrics.router)
app.include_router(permanent_commission.router)
app.include_router(insurance_auth.router)
app.include_router(push_wallet.router)
app.include_router(notifications.router)
app.include_router(job_board.router)
app.include_router(job_import.router)
app.include_router(hiring.router)
app.include_router(chat_sync.router)


@app.get("/health")
def health():
    return {
        "status": "ok",
        "nts_configured": bool(settings.nts_api_key),
        "toss_configured": bool(settings.toss_secret_key),
        "toss_client_configured": bool(settings.toss_client_key),
        "database_url": settings.database_url.split("://", 1)[0],
        "insurance_cert_provider": (
            "codef"
            if settings.codef_client_id
            else "hyphen"
            if settings.hyphen_api_key
            else "mock"
        ),
        "simple_auth_provider": (
            "barocert"
            if settings.barocert_link_id
            else "portone"
            if settings.portone_api_secret
            else "mock"
        ),
        "juso_configured": bool(settings.juso_confm_key),
        "kakao_geocode_configured": bool(settings.kakao_rest_api_key),
        "reverify_batch_enabled": settings.reverify_batch_enabled,
        "reverify_batch_interval_hours": settings.reverify_batch_interval_hours,
    }
