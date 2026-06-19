# Workflow State

## Current Task

- **Cursor Agents iljali-app 대화 재연결** — done (125 chats retagged)

## Backlog (priority order)

1. [x] **실 PG + 서버 영속화** — Toss 서버 경유·DB·스크래핑 (2026-06-12)
2. [ ] **급여지급일 서버/API** — monthly rule 필드 영속화
3. [ ] **카카오 알림톡 실연동** — notifications stub → Bizmessage
4. [ ] **근태 달력 — table_calendar / 백그라운드 geofence** — MVP 이후

## Definition of Done

- `flutter analyze` — **0 errors** (new files)
- `flutter test` — commute tests pass
- Pricing/copy matches final push policy
- `workflow_state.md` updated

## Progress

- [x] **Cursor Agents iljali-app 대화 재연결** — 125 chats retagged to D:\1jari; chat-archive index exported

- [x] **일자리 알림핀 색상 피커 통일** — `ShuttleRouteColorPicker` 재사용, 6색 스와치 제거, shuttle color utils test pass

- [x] **황금핀 제거 + 무료 기업 지도 열람** — premiumPartner 삭제, CorporateMapContentAccessPolicy, paywall, 25 tests pass

- [x] **셔틀 노선 근무지 고정 UX** — split/merge stops, pinned workplace row, edit page refactor, tests 18 pass

- [x] **정류장 표시핀 노출 잠금** — paid map + exposureActivated reconcile; isShuttleExposureActive; payment delta-only; tests 11 pass

- [x] **PUSH 이용권 결제/사용 UX** — 결제=수량 stepper 바텀시트; 사용=지도+체크박스; analyze 0 errors

- [x] **정류장 표시핀 다노선 일괄 결제** — multi-expand routes, sticky checkout bar, `activateSelectedBatch`
- [x] **정류장 표시핀 결제 checkout** — paymentKind on PushPaymentBundle; checkout UI product/breakdown labels
- [x] **셔틀 연결 UX** — badge 3-state, phase labels, info banner, confirm dialog, helper copy
- [x] **신규 공고 셔틀 overlay 연결** — ShuttleStopActivationPageResult, write page `_hasShuttleRouteOverlay`, panel link action
- [x] **A/B 결제 위임 UX** — optional services panel labels + payOrRequest PUSH; B-side requester name; entity field
- [x] **일자리 알림핀 UX + 정류장 표시핀 naming** — config/payment split, JobPinActivationPage, grep clean
- [x] **PushRadiusMapPicker Naver Map** — Naver on mobile; mock pan/zoom fix; coord overlay removed; commute/corporate maps unified
- [x] **이용권 상점 naming cleanup** — 일자리/PUSH 이용권 rename, long descriptions, 10회 팩 no copy; tests 8 pass
- [x] **일용직 안내 UX + 고시급 핀** — DailyWorkerPolicy dialog/gate/auto payment date; premiumWage sky-blue pin; tests 16 pass
- [x] **근태 달력 UX + 급여 계산** — EasySalaryCalculator, AttendanceMonthCalendar, 300m proximity banner, employer headcount/filter, tests 6 pass
- [x] **이용권 상점 redesign** — 8 SKU catalog, vertical sections, wallet bar removed, tests 11 pass
- [x] **Optional services panel copy** — `공고는 더 넓게` / `모집은 더 빠르게` headers; commute/push labels; redundant helper copy removed
- [x] **푸시→PUSH terminology** — ~186 replacements across `lib/` user-facing strings; `extra_push_availability_test` updated
- [x] **AI 공고 가져오기 홈 진입** — entry sheet, shell import path, write AppBar 가져오기
- [x] **Billing UX copy audit** — 근무지/일자리 알림핀 terminology, shop wallet copy, create route, edit/write symmetry
- [x] **공고 카드·미리보기 라벨 UX** — bold labels, 시급 중복 제거, 근무일시 prefix
- [x] **공고보기 → 홈 지도 미리보기** — shell focusPostId, map pin + bottom panel
- [x] **공고 수정 화면 셔틀 노선 연결** — `corporate_edit_job_post_page`
- [x] **공고 가져오기 워딩·AI 아이콘** — `JobPostImportCopy` / `AiSparkleMark`
- [x] **셔틀 노선·정류장 UX (구인자)** — 주소/지도 핀, 이름·탑승시각 입력·수정 (`shuttle_route_edit_page`)
- [x] **셔틀 노선 맵 오버레이 (구직자)** — 핀 탭 시 정류장→근무지 점선 경로 + 정류장명·시각 표시
- [x] ShuttleRouteEntitlement — `commuteRouteId`만으로 노선 오버레이 노출
- [x] ShuttleBooking entity + ShuttleBookingRepository
- [x] JobApplication/HiringApplication shuttle·근태 필드 확장
- [x] NearestShuttleStopService + ShuttleReminderService
- [x] 구직자 상세·지원 2단계 플로우 (교대·셔틀)
- [x] 내 지원 탭 Coupang Flex 스타일 섹션
- [x] QR 출근 + CorporateShuttleAttendanceHubPage
- [x] 데모 시드 seeker-alpha 셔틀 예약
- [x] commute tests 12 pass (`commute_route_polyline`, entitlement 갱신)

- [x] **셔틀 오버레이 유료 활성화 UI** — service + ShuttleOverlayActivationSection, published/edit/posts tab, tests 4 pass
- [x] **기업 노출·푸시 정책** — 현재 노출중 라벨, 셔틀 오버레이 게이트, 자동 푸시 제거, tests 10 pass
- [x] **결제 권한·조직 MVP** — BRN org repo, payer resolver, 결제 관리 UI, tests 11 pass
- [x] **Billing compile fixes** — PushBasePointArgs navigation file, exposure activation in base point page, attendance test appliedAt

- [x] **Expired job post reactivation** — workplace 미이용중 tile + ReactivateCorporateJobPostUseCase + tab dialog

## Completed (recent)

- 2026-06-18 — **Cursor Agents iljali-app 대화 재연결** — 125 chats retagged; `.cursor/chat-archive/` index

- 2026-06-18 — **일자리 알림핀 색상 피커 통일** — ShuttleRouteColorPicker 재사용, 6색 스와치 제거, shuttle color utils test pass

- 2026-06-18 — **황금핀 제거 + 무료 기업 지도 열람** — 3-tier pins, map intel gating, PUSH_PACKAGE_PRICING updated, 25 tests pass

- 2026-06-18 — **셔틀 노선 근무지 고정 UX** — pinned 근무지 row, split/merge policy, edit page refactor, 18 commute tests pass

- 2026-06-18 — **정류장 표시핀 노출 잠금** — paid map reconcile, delta-only payment, 11 unit tests pass

- 2026-06-18 — **PUSH 이용권 결제/사용 UX** — 결제 바텀시트(수량 stepper); 사용=지도+ExpansionTile; purchase page 라우트 래퍼
- 2026-06-18 — **정류장 표시핀 결제 checkout** — paymentKind on bundle; checkout shows 정류장 표시핀 not PUSH 알림권
- 2026-06-18 — **셔틀 연결 UX 명확화** — 회사 노출 vs 공고 연결 분리, 연결 필요 badge, confirm dialog, helper copy
- 2026-06-18 — **신규 공고 셔틀 overlay 연결** — activation page link button, write page overlay flag, panel badge/link action
- 2026-06-17 — **일자리 알림핀 UX + 정류장 표시핀 naming** — JobPinActivationPage, config-only base point page, panel split row, lib/ grep clean

- 2026-06-17 — **이용권 상점 naming cleanup** — 일자리/PUSH 이용권, long descriptions, 10회 팩 no copy, tests 8 pass

- 2026-06-15 — **일용직 안내 UX + 고시급 하늘색 핀** — acknowledgment dialog, auto 급여지급일, premiumWage tier (≥11,320), tests 16 pass

- 2026-06-15 — **근태 달력 UX + 쉬운 급여 계산** — job detail calculator, seeker/corp calendar tabs, 300m proximity alert, employer N명 filter, tests 6 pass

- 2026-06-15 — **이용권 상점 redesign** — 일자리핀·정류장핀·PUSH 알림권·PUSH 단독 8 SKU, 세로 목록, analyze 0 errors

- 2026-06-15 — **AI 공고 가져오기 홈 진입** — `corporate_create_job_post_entry_sheet`, shell + write AppBar, tests pass

- 2026-06-15 — **Expired job post reactivation** — 미이용중 tile, 재등록 usecase, tab AlertDialog, test 1 pass

- 2026-06-14 — **셔틀 오버레이 유료 활성화 UI** — 알림핀 1회 소비, published/edit/posts tab, ShuttleOverlayActivationService tests 4 pass
- 2026-06-14 — **기업 노출·푸시 정책 분리** — 활성화≠푸시, 셔틀 hasShuttleRouteOverlay 게이트, 자동 push-dispatch 제거
- 2026-06-13 — **기업 결제 권한·조직 계층 MVP** — SharedPreferences org, 위임, 수수료 라우팅, 결제 관리 탭
- 2026-05-28 — **셔틀 노선 E2E** — 구인자 정류장 이름·시각 폼, 구직자 맵 점선·근무지 연결, polyline test
- 2026-05-28 — **노출·거점 UX** — 사업소재지 1km 무료, 추가 거점만 유료(등록 전 upsell 제거)
- 2026-05-28 — 셔틀 정류장 **지도에서 선택** (`ShuttleStopMapPickerPage` + 노선 수정 UI)
- 2026-06-09 — 물류 셔틀 채용 MVP (7 phases, 10 commute tests)
- 2026-06-09 — 셔틀 노선 지도 오버레이 MVP (corp-alpha 다이소 데모·5 tests)
- 2026-06-08 — 공고 간결등록 MVP 데모 (데모 채우기·공고탭 바로가기·parser test)
- 2026-06-08 — YOLO 서비스 준비도 배치 30항목 (UX·API·서버·CI·테스트)

## Blockers

- **서버 pytest**: 로컬 venv 미구성
- **analyze**: `showsShuttleRouteOverlay` 관련 기존 4 errors (extension import, pre-existing)

## Verification

- Tests: pin tier / map access / visual theme — 25 pass
- Lint: analyze on changed files — 0 errors
