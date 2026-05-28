# Workflow State

## Current Task

- (idle) — MVP 제품 범위 feature flags + UI 게이트 완료

## Backlog (priority order)

1. [ ] **급여지급일 서버/API** — monthly rule 필드 영속화 (현재 로컬 in-memory만)
2. [x] **서버 wallet API** — BRN 보너스·패키지 크레딧 영속화 (FastAPI `/v1/wallet/*`)
2. [x] **공고 `jobDescription` 필드** — `CorporateJobPost` 분리, 작성/수정 플로우 반영
3. [x] **enum `standard700m` 리네임** — `standardFree1km` (동작 1km 유지)
4. [x] **Android Gradle 9.1** — wrapper 9.1.0; duplicate launcher color 제거; APK 빌드 재시도 중
5. [x] **ROI 대시보드** — BASIC 티어 문구 → 출근 확인(10,000원/건) 기준
6. [x] **analyzer warnings** — unused/duplicate import 11건 정리

## Definition of Done

- `flutter analyze` — **0 errors**
- `flutter test` — **all pass**
- Pricing/copy matches `map/PUSH_PACKAGE_PRICING.md`
- `workflow_state.md` updated (Progress, Verification, Backlog checkboxes)

## Progress

- [x] MVP 제품 범위 — `ProductFeatureFlags` + 일용직-only UI 게이트 + disabled_features.md
- [x] 지원자 모집하기 — 공고 카드 탭 시 지도 확인 시트 → 확인 후 크레딧 소진
- [x] 푸시 거점 UX — AI 1km+거점 추천, 기본 거점 검색 숨김, 안내 카드 카피
- [x] Worker-type 급여지급일 UX — 일용직 달력 / 일반·계약 당월·익월 N일
- [x] Autonomous rules + Backlog template added (2026-05-28)
- [x] Package-first stability — docs, copy, 100 tests
- [x] 서버 wallet API 스키마·라우터·pytest 초안
- [x] jobDescription 필드 + fullDescriptionText 호환
- [x] PushRadiusTier.standardFree1km 리네임
- [x] Gradle 9.1 wrapper + ic_launcher 중복 리소스 제거
- [x] ROI copy (출근 확인 10,000원/건)
- [x] analyzer unused import 정리

## Completed (recent)

- 2026-05-28 — MVP scope: ProductFeatureFlags (일용직-only default), UI gates, disabled_features.md; 11 tests pass.
- 2026-05-28 — 지원자 모집하기: 공고 카드 → 지도·반경 확인 bottom sheet → 확인 후 PushDispatchService 소진; extra_push_confirm_sheet_test 3 pass.
- 2026-05-28 — 푸시 거점 설정 UX: AI 1km·거점 추가 추천, 기본 거점 검색/드래그 비활성, 안내 카드 카피 개선; push tests 11 pass.
- 2026-05-28 — 급여지급일: `SalaryPaymentSchedule`, `workerCategory` on post, form 분기, 117 tests pass.
- 2026-05-28 — Autonomous backlog 6항목: wallet API, jobDescription, enum rename, Gradle 9.1, ROI copy, lint cleanup.
- 2026-05-28 — Autonomous execution rule + workflow Backlog/DoD.
- 2026-05-28 — Copy/docs sweep: 100 tests, 0 analyze errors, package-first UI aligned.

## Blockers

- **서버 pytest**: 로컬 `python`/`venv` 미구성 — `server/.venv` 생성 후 `pip install -r requirements.txt` · `pytest tests/test_push_wallet.py` 필요.
- **APK 빌드**: 세션에서 JAVA_HOME(Android Studio JBR) 설정 후 빌드 시도; Gradle 9.1 태스크는 기동됨. 최종 green은 로컬에서 `flutter build apk` 재확인 권장.

## Verification

- Tests: product_feature_flags + corporate_create_job_post_wizard — **11 passed**
- Tests: extra_push_confirm_sheet — **3 passed**
- Tests: corporate/ — **71 passed, 1 failed** (pre-existing `partnership_downgrade_home_test` 1km copy)
- Lint: `flutter analyze` — **0 errors** on changed files
- Server: wallet pytest — **not run** (no Python venv in agent shell)
- APK: `flutter build apk --debug` — Gradle 9.1 ran; duplicate resource fixed; full green pending local JAVA_HOME + rebuild

## Session kickoff (copy to chat)

```
Backlog 처리. workflow_state.md·PUSH_PACKAGE_PRICING.md 기준.
묻지 말고 plan→execute→verify→다음 항목 반복. 커밋 X.
```
