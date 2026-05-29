# Workflow State

## Current Task

- **급여지급일 서버/API** — monthly rule 필드 영속화 (현재 로컬 in-memory만)

## Backlog (priority order)

1. [ ] **급여지급일 서버/API** — monthly rule 필드 영속화 (현재 로컬 in-memory만)
2. [x] **FINAL push policy** — 무료 등록·10공고 상한·지역 푸시권·구직자 푸시함 30일
3. [x] **서버 wallet API** — BRN 보너스·패키지 크레딧 영속화 (FastAPI `/v1/wallet/*`)

## Definition of Done

- `flutter analyze` — **0 errors**
- `flutter test` — **all pass**
- Pricing/copy matches final push policy
- `workflow_state.md` updated

## Progress

- [x] PushWalletCreditPolicy — registration always free; dispatch uses daily free or regional tickets
- [x] PushDispatchService — no credit consumption on registration
- [x] JobPostLimitPolicy + data source enforce 10 active posts per companyKey (auto-close oldest)
- [x] UI rebrand 패키지 → 지역 푸시권(황금핀); registration banner + post-registration upsell
- [x] SeekerPushInbox — entity, repository, 30-day retention, archive/delete, page + route
- [x] Tests: policy, limit, retention, availability, confirm sheet — pass
- [x] FINAL policy 카피 정합화 — 무료 등록/근무지 무료 푸시/유료 지역 푸시권/황금핀 조건 문구 전면 정리
- [x] Corporate flaky/legacy expectations 정리 — `corporate_home_shell_test` 포함 정책 반영값으로 갱신

## Completed (recent)

- 2026-05-29 — FINAL policy audit+polish: corporate/seeker copy 정합화, 혼동 문구(이용권/패키지) 정리, corporate tests 전체 통과(115)
- 2026-05-29 — FINAL push policy: free registration, 10-post limit, 지역 푸시권 rebrand, seeker push inbox 30-day; corporate tests 112 pass (2 pre-existing home_shell fail)
- 2026-05-28 — 크레딧 UI 분리: 패키지/일일 무료 카드 배지 분리

## Blockers

- **서버 pytest**: 로컬 venv 미구성

## Verification

- Tests: `flutter test test/features/corporate/` — **115 passed, 0 failed**
- Tests: `flutter test test/features/job_seeker/seeker_push_retention_policy_test.dart` — **2 passed**
- Lint: `flutter analyze lib/features/corporate lib/features/job_seeker` — **0 errors** (warnings only)
