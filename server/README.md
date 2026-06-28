# Iljari Compliance API

FastAPI 백엔드 — 사업자 검증, 토스 결제, 푸시·거점 지갑, 공고·지원·채팅 동기화, 외부 공고 스크래핑.

## 운영 (NCP — 기본 테스트 대상)

| 항목 | 값 |
|------|-----|
| API | `http://api.iljari.app:8000` |
| 서버 | `iljari-api-01` (`211.188.56.77`) |
| 코드 | `/opt/iljari/server` (Docker Compose) |
| 헬스 | `GET /health` |

```bash
curl http://api.iljari.app:8000/health
# Mac에서 QC 시드
./scripts/seed_ncp_server.sh
```

Flutter·QC 스크립트는 **맥에서 UI만 실행**, API·DB는 위 서버를 사용합니다 (`scripts/remote_api.env`).

## 로컬 실행 (SQLite, opt-in)

```powershell
cd d:\1jari\server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
# .env: NTS_API_KEY, TOSS_SECRET_KEY, TOSS_CLIENT_KEY 등 설정
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

헬스체크: `GET http://127.0.0.1:8000/health`

## Docker (PostgreSQL)

```powershell
cd d:\1jari\server
copy .env.example .env
# TOSS_SECRET_KEY, NTS_API_KEY 등 프로덕션 값 입력
docker compose up --build
```

API: `http://localhost:8000` · DB: PostgreSQL 16 (`iljari` / `iljari`)

## Staging HTTPS (nginx + Postgres)

로컬 self-signed TLS 또는 실서버 Let's Encrypt.

```bash
# repo root
./run_staging.sh
```

1. `server/staging/env.example` → `server/.env.staging` (자동 복사)
2. `/etc/hosts`: `127.0.0.1 app.staging.iljari.local api.staging.iljari.local`
3. App `https://app.staging.iljari.local` · API `https://api.staging.iljari.local`
4. Toss 웹훅: `https://api.staging.iljari.local/v1/payments/webhook/toss`

실서버: `STAGING_APP_HOST` / `STAGING_API_HOST`를 실제 도메인으로 바꾸고 certbot으로 `server/staging/certs/fullchain.pem`·`privkey.pem` 교체.

| 변수 | 용도 |
|------|------|
| `PAYMENT_WEB_SUCCESS_URL` | Toss 웹 결제 성공 리다이렉트 |
| `PAYMENT_WEB_FAIL_URL` | Toss 웹 결제 실패 리다이렉트 |
| `SIMPLE_AUTH_CALLBACK_URL` | 간편인증 콜백 (공개 HTTPS 필수) |

## 환경 변수

| 변수 | 용도 |
|------|------|
| `DATABASE_URL` | `sqlite:///./iljari_compliance.db` (기본) 또는 `postgresql+psycopg2://...` |
| `NTS_API_KEY` | 국세청 사업자 검증 |
| `TOSS_SECRET_KEY` | 토스 서버 시크릿 (`test_sk_` / `live_sk_`) — 미설정 시 mock 결제 |
| `TOSS_CLIENT_KEY` | 토스 클라이언트 키 (`test_ck_` / `live_ck_`) — checkout URL |
| `TOSS_WEBHOOK_SECRET` | 토스 웹훅 서명 검증 |
| `CORS_ORIGINS` | 허용 origin (쉼표 구분, 기본 `*`) |
| `JOB_SCRAPE_*` | 외부 공고 스크래핑 타임아웃·rate limit |

전체 목록: `.env.example`

## 주요 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| GET | `/health` | 서비스·키 설정 상태 |
| POST | `/v1/compliance/business/verify` | 사업자 검증 |
| POST | `/v1/payments/charge` | 결제 시작 (checkout URL 또는 mock) |
| POST | `/v1/payments/confirm` | 토스 결제 승인 확인 |
| POST | `/v1/payments/webhook/toss` | 토스 웹훅 |
| GET | `/v1/wallet/{company_key}` | 푸시·거점 지갑 |
| GET | `/v1/job-board/posts` | 공고 목록 (DB 영속화) |
| POST | `/v1/job-import/parse` | 외부 URL 스크래핑·텍스트 파싱 |
| GET | `/v1/hiring/applications` | 지원 목록 |
| GET | `/v1/chat-sync/{id}/messages` | 채팅 메시지 |

## Flutter 연동

```bash
# 기본 (NCP)
flutter run -d chrome --dart-define=COMPLIANCE_API_URL=http://api.iljari.app:8000
# 또는
./run_web.sh
```

- 로컬 API: `ILJARI_API_MODE=local ./run_web.sh` → `http://127.0.0.1:8000`
- Android 에뮬 + 로컬 API: `http://10.0.2.2:8000`

결제: `COMPLIANCE_API_URL` 설정 시 `RemotePaymentsGatewayService` → 서버 `/v1/payments/charge` → WebView checkout → `/v1/payments/confirm`

## 테스트

```powershell
cd d:\1jari\server
pytest tests/ -q
```
