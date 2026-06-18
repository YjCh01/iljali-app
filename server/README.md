# Iljari Compliance API

FastAPI 백엔드 — 사업자 검증, 토스 결제, 푸시·거점 지갑, 공고·지원·채팅 동기화, 외부 공고 스크래핑.

## 로컬 실행 (SQLite)

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

```powershell
cd d:\1jari
flutter run -d chrome --dart-define=COMPLIANCE_API_URL=http://127.0.0.1:8000
```

- Android 에뮬레이터: `http://10.0.2.2:8000`
- 실기기·스테이징: 배포된 API URL

결제: `COMPLIANCE_API_URL` 설정 시 `RemotePaymentsGatewayService` → 서버 `/v1/payments/charge` → WebView checkout → `/v1/payments/confirm`

## 테스트

```powershell
cd d:\1jari\server
pytest tests/ -q
```
