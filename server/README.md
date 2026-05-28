# Iljari Compliance API

FastAPI 백엔드 — 사업자 검증(OCR+국세청), 연락 entitlement, 파트너십 구독, 관리자 컴플라이언스.

## 실행

```powershell
cd d:\1jari\server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
copy .env.example .env
# .env 에 NTS_API_KEY 설정 (공공데이터포털 odcloud)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 주요 엔드포인트

| Method | Path | 설명 |
|--------|------|------|
| POST | `/v1/compliance/business/verify` | 사업자 검증 |
| GET | `/v1/compliance/entitlements/contact?company_key=` | 연락 가능 여부 |
| POST | `/v1/subscriptions/subscribe` | 파트너십 월정액 구독 |
| GET | `/v1/admin/compliance/flags` | 이상행위 플래그 |
| PATCH | `/v1/admin/companies/{key}/review` | 관리자 승인/거부 |
| PATCH | `/v1/admin/companies/{key}/suspend` | 계정 정지 |
| GET | `/v1/wallet/{company_key}` | 푸시·거점 지갑 조회 |
| PUT | `/v1/wallet/{company_key}` | 지갑 상태 저장 |
| POST | `/v1/wallet/{company_key}/credits` | 패키지 크레딧 추가 |
| GET | `/v1/wallet/{company_key}/bonus` | BRN 보너스 수령 여부 |
| POST | `/v1/wallet/{company_key}/bonus/claim` | 신규 사업자 보너스 5회 지급 |

Flutter 앱: `EnvConfig.complianceApiBaseUrl = 'http://10.0.2.2:8000'` (Android 에뮬레이터)
