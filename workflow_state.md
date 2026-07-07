# Workflow State

## Current Task

- **지원자 채팅 검증 제한 제거** — 완료

## Backlog (priority order)

1. [ ] **어드민 셔틀 참여자 UI** — `/shuttle/participants` 패널 카드
2. [ ] **AdaptiveSheet (웹 우측 패널)** — 결제·알림핀·정류장 핵심만
3. [ ] **QC DB 스냅샷** — export/import SQL for team-shared baseline
4. [ ] **공고 full JSON sync** — CorporateJobPost 전체 필드 server payload
5. [ ] **실 PG E2E** — Toss sandbox + webhook
5. [ ] **급여지급일 서버/API** — monthly rule 필드 영속화
6. [ ] **카카오 알림톡 실연동** — notifications stub → Bizmessage
7. [ ] **근태 달력** — table_calendar / geofence MVP 이후

## Definition of Done

- `flutter analyze` — **0 errors** (new files)
- `flutter test` — commute tests pass
- Pricing/copy matches final push policy
- `workflow_state.md` updated

## Progress

- [x] **지원자 채팅 검증 제한 제거** — 서버 `evaluate_contact`·클라이언트 entitlement·지원자/채팅 탭 제한 카드 제거, pytest 2 pass

- [x] **내 버스 세로 노선 타임라인** — `ShuttleRouteVerticalTracker`, seeker my-bus 연동, timeline position test 4 pass

- [x] **셔틀 서버 영속화** — commute_routes·preferences API, repo 서버 우선, pytest 4 pass

- [x] **통근버스 PRD** — 근무지 도착시각·첫정류장 필수, 노선공유 opt-in, 1노선1정류장, ±30분 추적, 관제탑 동의, `shuttle_route_schedule_test` 4 pass

- [x] **셔틀 근무 시작시간 + 내 버스** — admin work_start_time + 확인 다이얼로그, KST 도착 간주 시 추적 중지, 지원·근무 탭 「내 버스」 지도+ETA, pytest 6 pass

- [x] **실시간 셔틀 위치 파일럿** — 어드민 휴대폰 검색·회사/노선 지정·오늘 위치 세션 중지, 담당자 30초 자동 위치 공유, 같은 회사·같은 셔틀 탑승자 20초 추적

- [x] **Admin Web Console Phase A** — shell, 6 panels, stats API, run_admin.sh, Admin 실행.command

- [x] **QC·Admin Ops MVP** — admin_ops API, sync bootstrap, AdminOpsPage, seeker 1000 seed, run_qc, QC_MODE mock PG; flutter analyze 0 errors

- [x] **웹 PUSH·정류장 지도 `_createWrapper` fix** — Circle/Marker/Polyline `callConstructor`; Mac `run_web.sh` + `네이버키_설정.sh`; map tests 3 pass

- [x] **웹 주소 검색 Phase 3** — `DaumPostcodeWebEmbed` (Kakao Postcode JS), `WorkplaceAddressPlatform.isPostcodeSupported`, 근무지 검색 웹 Daum 플로우, web build + 7 tests pass

- [x] **웹 NAVER Phase 2** — 원(반경)·폴리라인·PushRadiusWebMapPicker·셔틀 오버레이, web build + 3 tests pass

- [x] **웹 NAVER 실지도 Phase 1** — `NaverMapWebWidget` JS v3, 구직자·기업 홈, web build pass

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

- 2026-07-07 — **내 버스 세로 노선 타임라인** — 공항버스 스타일 노선·정류장·버스 위치 UI, seeker my-bus 연동, test 4 pass

- 2026-07-04 — **실시간 셔틀 위치 파일럿** — A 담당자 위치 공유 + 같은 회사·같은 셔틀 오늘 탑승자 추적; pytest 5 pass; changed Dart analyze no issues

- 2026-06-19 — **웹 PUSH·정류장 지도 + Mac** — NAVER Circle overlay js interop fix; `run_web.sh`; map tests 3 pass
- 2026-06-19 — **웹 주소 검색 Phase 3** — DaumPostcodeWebEmbed, Chrome 근무지 Daum 플로우, Kakao geocode, web build + 7 tests pass

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

- none

## Verification

- Tests: `flutter test test/features/commute/shuttle_bus_timeline_position_test.dart` — 4 passed
- Lint: `flutter analyze` on commute timeline files — 0 errors (info only)
