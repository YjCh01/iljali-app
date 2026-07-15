from pydantic import field_validator
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
    # true/false 강제. 비우면 toss_secret_key 미설정 시 무료 노출 프로모션 ON
    free_exposure_promo: str = ""
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
    require_clova_ocr: bool = False

    # 공고 본문 이미지 — FastAPI StaticFiles `/media/job-posts`
    job_media_dir: str = "./uploads/job-media"
    api_public_base_url: str = "http://127.0.0.1:8000"

    # Firebase Cloud Messaging — 서비스 계정 JSON (한 줄 문자열)
    fcm_service_account_json: str = ""

    # 소셜 로그인 OAuth (미설정 시 mock 모드)
    social_auth_mock: bool = False
    social_app_success_url: str = "https://iljari.app/auth/social-complete"
    kakao_oauth_client_id: str = ""
    kakao_oauth_client_secret: str = ""
    naver_oauth_client_id: str = ""
    naver_oauth_client_secret: str = ""
    google_oauth_client_id: str = ""
    google_oauth_client_secret: str = ""

    @property
    def is_free_exposure_promo(self) -> bool:
        raw = self.free_exposure_promo.strip().lower()
        if raw in ("1", "true", "yes", "on"):
            return True
        if raw in ("0", "false", "no", "off"):
            return False
        return not bool(self.toss_secret_key)

    @field_validator(
        "kakao_oauth_client_id",
        "kakao_oauth_client_secret",
        "naver_oauth_client_id",
        "naver_oauth_client_secret",
        "google_oauth_client_id",
        "google_oauth_client_secret",
        "kakao_rest_api_key",
        mode="before",
    )
    @classmethod
    def _strip_oauth_secrets(cls, value: object) -> object:
        if isinstance(value, str):
            return value.strip()
        return value


settings = Settings()
