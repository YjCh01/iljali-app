# 일자리(map) — 서비스 준비도 가이드

MVP에서 **실제 서비스 오픈**까지 남은 작업과, 지금 동작하는 범위를 정리합니다.

## 지금 바로 쓸 수 있는 것 (로컬·데모)

| 영역 | 상태 |
|------|------|
| 기업 공고 무료 등록 | ✅ |
| 일자리 알림핀 (가입 2 + 검증 5, 구매 mock) | ✅ |
| 구직자 지도·보관함·지원·채팅 | ✅ |
| 근무예정 합의 → 근태/출근 | ✅ | 메인 앱 채용 성공 수수료 없음 (`ENABLE_HIRING_COMMISSION=false`) |
| 개발 테스트 계정 4종 + 시드 공고·채용·지원 데이터 | ✅ |
| E2E repository 테스트 | ✅ |
| 고객센터·약관·알림설정·지도 코치마크 | ✅ |
| 보관함 폴더 이름변경·삭제·시급 비교 | ✅ |
| 서버 DB 영속화 (job_board, hiring, chat_sync, payments) | ✅ |
| Flutter API 클라이언트 + sync | ✅ |
| 토스 결제 서버 경유 (mock/sandbox) | ✅ |
| 외부 공고 URL 서버 스크래핑 | ✅ |
| 결제 후 서버 지갑 충전 (`COMPLIANCE_API_URL` 시) | ✅ |

**데모 실행**

```powershell
cd d:\1jari
flutter run -d chrome
.\scripts\dev-run.ps1
```

시작 화면 → **개발 테스트 로그인** → 구직자 알파 / 기업 알파

---

## YOLO 스프린트 완료 항목 (2026-06-08)

### Flutter UX
1. `user_onboarding_flags.dart` — SharedPreferences 코치마크 플래그
2. `map_area_search_coach_banner.dart` + `individual_map_tab` 연동
3. `seeker_notification_settings_page.dart` — 로컬 알림 토글
4. `customer_support_page.dart` — FAQ + iljariapp@gmail.com
5. `legal_documents_page.dart` — 약관 9종 + 형광펜
6. `app_routes.dart` / `app.dart` — 신규 라우트
7. `individual_more_tab` — 알림설정·고객센터·약관·보관함 (MVP 스낵바 제거)
8. `job_bookmark_vault_repository` — `deleteFolder` / `renameFolder`
9. `individual_vault_tab` — 폴더 long-press 메뉴, 2건 시급 비교
10. `push_package_shop_page` — `loadWalletDetailed` + 보너스 SnackBar
11. `corporate_more_tab` — 고객센터·약관 링크
12. `web/index.html` — title/description 일자리
13. `corporate_welcome_onboarding` — 알림핀 2+5 슬라이드
14. `individual_applications_tab` — 채팅 연결 시 「채팅하기」
15. `member_login_gateway` — 개발 테스트 로그인 안내

### Dev/Seed
16. `dev_test_data_seeder` — seeker JobApplicationRepository 시드
17. corp-beta 지갑 — alpha와 동일 구성 확인

### Server
18. `job_board.py` — in-memory CRUD
19. `hiring.py` — applications list/create
20. `chat_sync.py` — messages append/list
21. `main.py` — 라우터 등록, notifications 중복 import 수정

### Flutter API
22. `iljari_api_client.dart`
23. `local_remote_sync_service.dart`

### Docs/CI
24. `PUSH_PACKAGE_PRICING.md` — 코드 정합 (가입2·검증5·무료일일 없음)
25. `README.md`
26. `scripts/dev-run.ps1`
27. `.github/workflows/flutter-test.yml`

### Tests
28. `job_bookmark_folder_ops_test.dart`
29. `push_package_catalog_test.dart`
30. `iljari_api_client_test.dart` (URL 없으면 skip)

---

## 서비스 오픈 전 필수 (P0)

| # | 항목 | 상태 | 비고 |
|---|------|------|------|
| 1 | **실 PG 연동** | 코드 완료 | `server/.env`에 `TOSS_SECRET_KEY` + `TOSS_CLIENT_KEY` (토스 가맹점) |
| 2 | **백엔드 배포** + `COMPLIANCE_API_URL` | 코드 완료 | `docker compose up` 또는 호스팅 후 Flutter dart-define |
| 3 | **네이버 지도 Client ID** | 미설정 | `NAVER_MAP_CLIENT_ID` |
| 4 | **앱 서명·스토어 등록** | 미설정 | |
| 5 | **약관·개인정보** | 초안 완료 | `store/legal/` — 법무 검토·시행일·LBS 신고번호 남음 |
| 6 | **서버 영속화** | ✅ SQLite/PostgreSQL | 공고·지원·채팅·결제 원장 |

### PG·서버·스크래핑 설정 (2026-06-12)

**서버** (`server/.env`):

```
TOSS_SECRET_KEY=test_sk_...   # 토스 개발자센터
TOSS_CLIENT_KEY=test_ck_...
TOSS_WEBHOOK_SECRET=...       # 웹훅 등록 시
DATABASE_URL=sqlite:///./iljari_compliance.db
```

**Flutter** (기본 — NCP):

```
COMPLIANCE_API_URL=http://api.iljari.app:8000
ADMIN_API_KEY=iljari-admin-dev-key
```

로컬 API만 쓸 때: `ILJARI_API_MODE=local` + `http://127.0.0.1:8000`

**스크래핑**: `POST /v1/job-import/parse` + `url` — albamon·saramin·알바천국 등 HTML 수집 (일부 사이트는 봇 차단 가능).

---

## 출시 후 1~2주 (P1)

- 카카오 알림톡 Bizmessage 실연동
- 급여지급일 monthly rule 서버 저장
- 소셜 로그인
- 관리자 대시보드 운영 워크플로

---

## 검증 명령

```powershell
cd d:\1jari\server ; pytest tests/ -q
cd d:\1jari
flutter analyze
flutter test test/features/job_seeker/job_bookmark_folder_ops_test.dart
flutter test test/features/corporate/push_package_catalog_test.dart
flutter test test/core/api/iljari_api_client_test.dart
```
