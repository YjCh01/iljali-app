# 일자리 (map)

지도 기반 일용직·현장 채용 Flutter 앱 + FastAPI 컴플라이언스 서버.

## 빠른 시작

```powershell
cd d:\1jari
flutter pub get
flutter run -d chrome          # 웹 — NAVER_MAP_CLIENT_ID 있으면 실지도, 없으면 mock
flutter run -d windows         # PC (mock 지도)
$env:NAVER_MAP_CLIENT_ID='YOUR_WEB_CLIENT_ID'; .\scripts\dev-run.ps1
```

서버 (선택):

```powershell
cd d:\1jari\server
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
```

API URL 설정 (선택):

```powershell
flutter run -d chrome --dart-define=COMPLIANCE_API_URL=http://127.0.0.1:8000
```

## 개발 테스트 계정

시작 화면 → **개발 테스트 로그인**

| 역할 | 이메일 | 비밀번호 |
|------|--------|----------|
| 기업 α | corp-alpha@test.iljari.co.kr | Test1234! |
| 기업 β | corp-beta@test.iljari.co.kr | Test1234! |
| 구직 α | seeker-alpha@test.iljari.co.kr | Test1234! |
| 구직 β | seeker-beta@test.iljari.co.kr | Test1234! |

로그인 시 시드 공고·지원·채팅·근태 데이터가 자동 주입됩니다.

## 검증

```powershell
flutter analyze
flutter test
```

## 문서

- [PUSH_PACKAGE_PRICING.md](PUSH_PACKAGE_PRICING.md) — 알림핀 요금 (가입 2 + 검증 5)
- [SERVICE_READINESS.md](SERVICE_READINESS.md) — 서비스 오픈 체크리스트
