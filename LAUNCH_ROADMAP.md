# 출시 로드맵 (6단계)

> 코드·QC 기준 진행 체크리스트. `./run_qc.sh` / `./run_seeker_qc.sh` / `./run_corporate_web.sh`

## [0] 환경 고정

| 항목 | 상태 | 실행 |
|------|------|------|
| API + Flutter QC | ✅ | `./run_qc.sh` |
| 구직자 QC | ✅ | `./run_seeker_qc.sh` |
| 구인자 웹 QC (900px+) | ✅ | `./run_corporate_web.sh` |
| 구직자 웹 QC (900px+) | ✅ | `./run_seeker_web.sh` |
| Staging HTTPS (local) | ✅ | `./run_staging.sh` |
| Admin | ✅ | `./run_admin.sh` |
| server `.venv` 자동 | ✅ | `scripts/server_dev.sh` |

**남음:** `./scripts/staging/certbot-init.sh` (실서버 Let's Encrypt)

---

## [1] 구직자 탐색 테스트

| 항목 | 상태 |
|------|------|
| QC seeker 1000명 시드 | ✅ `seed_qc.py` |
| 서버 로그인 + bootstrap | ✅ `/v1/auth/login` |
| 지도·상세·지원 2단계 | ✅ |
| PUSH → 채팅 | ✅ |

**QC 계정:** `seeker-0001@qc.iljari.co.kr` / `QcTest1234!`

---

## [2] 구직자 QC + 버그

| 항목 | 상태 |
|------|------|
| 5탭 (내 일) | ✅ |
| 지원 → 서버 sync | ✅ `LocalHiringRepository._syncApplicationToServer` |
| 공고 좌표 hydrate | ✅ `workplace_latitude/longitude` |
| 보관함 캘린더 | ✅ `showKoreanDatePickerSheet` |

---

## [3] 출시 인프라 (P0)

| 항목 | 상태 | 비고 |
|------|------|------|
| 서버 Auth JWT | ✅ | `/v1/auth/login`, `/me` |
| SMS 인증 API | ✅ mock `123456` | Aligo: `SMS_PROVIDER=aligo` |
| Toss PG | 코드 ✅ | `.env` `TOSS_*` |
| 공고 서버 push + 좌표 | ✅ | |
| 지원 서버 create | ✅ | |
| Staging HTTPS | ✅ | `./run_staging.sh` — nginx + Postgres + self-signed |

---

## [4] 구인자 웹 QC

| 항목 | 상태 |
|------|------|
| CorporateWebScaffold | ✅ | 웹 900px+ **우측** 레일 |
| 구직자 웹 셸 | ✅ | `IndividualWebScaffold` — 우측 레일 |
| AdaptiveSheet (전체) | ✅ | `showAdaptiveSheet` — 모바일 bottom sheet / 웹 900px+ **우측** 패널 |
| 노출 연장 + 보유금 | ✅ |

---

## [5] 컴플라이언스

| 항목 | 상태 |
|------|------|
| 미인증 가입 + 등록증 | ✅ |
| Admin 승인 카드 | ✅ |
| NTS fail-closed (staging) | ✅ `REQUIRE_NTS_API_KEY=true` |
| OCR↔BRN 교차검증 | ✅ | BRN·상호·신뢰도·대표자명 |

---

## [6] 출시 마감

| 항목 | 상태 |
|------|------|
| 약관·개인정보 | ✅ 초안 9종 + PDF (`store/legal/`) + 앱 9탭 + 버전 `2026-01-01` |
| bundle ID | ✅ `kr.co.iljari.app` |
| Sentry/Crashlytics | ✅ | `sentry_flutter` + `SENTRY_DSN` |
| Toss PG E2E | ✅ | `scripts/staging/test_toss_e2e.sh` + webhook 테스트 |
| 웹 결제 콜백 | ✅ | `/payment-success` · `/payment-fail` |
| 약관 재동의 | ✅ | `LegalConsentGate` |
| 스토어 베타 | ✅ | listing·screenshots 가이드·`store_preflight.sh`·사업자 푸터·fastlane Appfile |

---

## 검증

```bash
cd server && pytest tests/ -q
flutter test test/features/corporate/exposure_renewal_policy_test.dart
flutter test test/features/job_seeker/individual_home_shell_test.dart
flutter test test/core/legal/business_disclosure_test.dart
./scripts/store_preflight.sh
```
