from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    nts_api_key: str = ""
    nts_validate_api_url: str = (
        "https://api.odcloud.kr/api/nts-businessman/v1/validate"
    )
    nts_status_api_url: str = (
        "https://api.odcloud.kr/api/nts-businessman/v1/status"
    )
    nts_api_url: str = "https://api.odcloud.kr/api/nts-businessman/v1/status"
    toss_secret_key: str = ""
    toss_client_key: str = ""
    clova_ocr_invoke_url: str = ""
    clova_ocr_secret: str = ""
    toss_webhook_secret: str = ""

    payment_web_success_url: str = "http://127.0.0.1:8081/payment-success"
    payment_web_fail_url: str = "http://127.0.0.1:8081/payment-fail"

    # 외부 공고 스크래핑
    job_scrape_timeout_sec: float = 15.0
    job_scrape_min_interval_sec: float = 1.0
    job_scrape_blocklist: str = "localhost,127.0.0.1"
    cors_origins: str = (
        "http://localhost:8080,http://localhost:8081,"
        "http://127.0.0.1:8080,http://127.0.0.1:8081"
    )
    database_url: str = "sqlite:///./iljari_compliance.db"

    # 건강보험 자격득실 — 1순위 CODEF / Hyphen
    codef_public_key: str = ""
    codef_client_id: str = ""
    codef_client_secret: str = ""
    hyphen_api_key: str = ""

    # 간편인증 — 2순위 Barocert / PortOne
    barocert_link_id: str = ""
    barocert_secret_key: str = ""
    portone_api_secret: str = ""
    simple_auth_callback_url: str = ""

    # CI 암호화 (서버 전용, 32자 이상 권장)
    insurance_ci_secret: str = ""

    codef_api_url: str = ""
    hyphen_api_url: str = ""
    barocert_api_url: str = ""
    barocert_allow_mock_fallback: bool = True
    portone_api_url: str = ""
    portone_channel_key: str = ""
    portone_allow_mock_fallback: bool = True

    # 30일 재직 확인 배치
    reverify_batch_enabled: bool = True
    reverify_batch_interval_hours: int = 6
    app_deep_link_scheme: str = "iljari"

    # 도로명주소 (행정안전부 Juso) + 좌표 (Kakao)
    juso_confm_key: str = ""
    kakao_rest_api_key: str = ""

    # QC·Admin Ops (로컬/QC 전용 — production 에서 반드시 교체)
    admin_api_key: str = "qc-admin-dev-key"
    qc_payment_mode: str = "wallet_only"

    # Auth / SMS (staging — mock when empty)
    auth_token_secret: str = ""
    sms_provider: str = "mock"
    sms_api_key: str = ""
    sms_mock_code: str = "123456"
    sms_aligo_user_id: str = ""
    sms_sender_id: str = ""
    require_nts_api_key: bool = False

    # 공고 본문 이미지 — FastAPI StaticFiles `/media/job-posts`
    job_media_dir: str = "./uploads/job-media"
    api_public_base_url: str = "http://127.0.0.1:8000"


settings = Settings()
