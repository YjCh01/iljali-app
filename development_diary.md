# Development Diary

## 2026-06-18 — 셔틀 노선 근무지 고정 UX

- **UX**: `ShuttleRouteStopRowList` — 상단 연보라 「+ 정류장 추가」, 경유 4행 스크롤, 하단 근무지 고정(비삭제·비재정렬)
- **Edit page**: `_intermediateStops` + `_workplaceStop` split; `mergeStops` on save; map `workplaceAdjustIndex` (-2)
- **Policy**: `splitRouteStops` legacy — 마지막 정류장 → 근무지 좌표; `mergeStops` 항상 말단 근무지
- **Polyline**: `pathIncludingWorkplace` — 저장된 근무지 중복 append 방지
- **Verify**: commute tests 19 pass; analyze 0 errors

## 2026-06-18 — 공고 카드 핀 요약 접기 UI

- **Problem**: 다수 일자리 알림핀·표시핀 시 카드가 세로로 과도하게 길어짐; 표시핀 개수 미표시
- **Fix**: `corporate_job_post_card` — 근무지(기본) 항상 표시, `일자리핀(N)`·`표시핀(N)` 접이 섹션 (`_CollapsiblePinSection`); 펼치면 개별 `_ExposureZoneRow` / `노선 i · N곳` 행
- **Status tile**: `JobPostExposureStatusLabels.shuttlePinCompact` — `표시핀 4 · 이용중`, `일자리핀 N · 설정됨` 등 카운트 포함
- **Verify**: `flutter analyze` 0 errors on changed files

## 2026-06-18 — 정류장 표시핀 노출 잠금 버그

- **Root cause**: `isShuttleExposureActive` false when paid map existed but `shuttleExposurePaidAt` null; `isShuttleStopExposureLocked` locked entire route when route missing from paid map; re-register dropped overlay/paid metadata; route edit only blocked on paid map entry not `exposureActivated`
- **Fix**: exposure extension — active when overlay + (paidAt OR paid map OR legacy); per-stop lock; `reconcileShuttleExposureWithRoutes`; activation/payment pages reconcile + preserve metadata on register; route edit blocks on any locked stop
- **Verify**: `shuttle_exposure_lock_test` 11 pass; related shuttle tests pass

## 2026-06-18 — PUSH 이용권 결제/사용 UX 분리

- **결제**: optional services panel → `showPushTicketPurchaseSheet` (수량 stepper · 결제수단 · 약관 · 결제하기); 지도/체크박스 제거
- **사용**: `PushTicketUsePage` → purchase-page 스타일 (지도 미리보기 · 일자리 알림핀/정류장 ExpansionTile · exposureActivated만 선택 · **사용하기**); PG 경로 제거 (walletCredit only)
- **호환**: `PushTicketPurchasePage` → 시트 래퍼 (`AppRoutes.corporatePushTicketPurchase` 유지)
- **Verify**: `flutter analyze` 0 errors on 4 files

## 2026-06-18 — 정류장 표시핀 다노선 일괄 결제

- **UX**: 여러 노선 동시 펼침 (`Set<int> _expandedRouteIndices`); 노선 카드별 per-route 미리보기; 카드 내 결제 버튼 제거; 하단 sticky bar `총 N곳 · KRW` + 빨간 결제하기
- **Service**: `activateSelectedBatch` — 전 노선 pending 합산, 지갑 크레딧·단일 `payOrRequest`; `activateSelected`는 batch 위임
- **Checkout**: `_checkoutAll` — 전 route upsert, preferredRouteId 우선 job post link, route별 overlay sync
- **Verify**: `shuttle_stop_activation_service_test` 2 pass; analyze 0 errors

## 2026-06-18 — 정류장 표시핀 결제 checkout 상품명 버그

- **Root cause**: 노출(19,900)과 PUSH 알림권(19,900) 단가 동일 → `PushPaymentBundle.productSummary`가 금액만으로 PUSH로 오판; checkout `_OrderSummaryCard`가 모든 `isExtraPush`에 「푸시 알림 ·」 하드코딩
- **Fix**: `paymentKind` (`JobPostPaymentRequestKind`) on bundle; `checkoutProductTitle`/`checkoutProductDetail`/`checkoutBreakdownLabel`; shuttle/job-pin services set kind; navigation args pass kind; checkout UI uses bundle helpers
- **Verify**: `push_package_catalog_test` +1; `flutter analyze` 0 errors on changed files

## 2026-06-18 — 셔틀 노선 연결 implicit UX

- **Rationale**: 정류장 표시핀은 공고 등록 후 유료 서비스 그리드에서만 설정; More 탭 선구성 노선은 `ShuttleStopActivationPage`에서 선택 — standalone 「이 공고에 노선 연결」 버튼 중복
- **ShuttleStopActivationPage**: expand 시 `_canLinkToJobPost`면 `_linkRouteToJobPostIfNeeded`로 silent link; `_linkedRouteId` 추적 후 뒤로가기 pop 시 `ShuttleStopActivationPageResult` 반환; 결제 버튼만 유지
- **Optional services panel**: orange info box·연결 버튼·`_linkShuttleOverlayToPost` 제거; footer·phase copy를 편집 진입 안내로 변경; `needsLink` 배지는 편집 전까지 유지
- **Verify**: `flutter analyze` 0 errors on changed files; lib 내 「이 공고에 노선 연결」 grep 0

## 2026-06-18 — 공고 등록 플로우: 유료 서비스 사후 선택

- **Write page**: optional services·`PushJobPostPaymentFlow` 제거; 최소 defaults로 등록 후 `CorporateJobPostPublishedArgs(post, workplace)`로 published 페이지 이동
- **Published page**: 성공 메시지 + 「공고 목록 보기」/「유료 결제 추가 (선택)」 그리드; bottom sheet에 `CorporateJobPostOptionalServicesPanel` (jobPostId·workplace); 변경 시 `updateJobPost` persist
- **Routing**: `CorporateJobPostPublishedArgs` 신규; legacy `CorporateJobPost` 인자 호환 (warehouseName → workplace)
- **Verify**: `flutter analyze` 0 errors on changed files (1 pre-existing info)

## 2026-06-18 — 신규 공고 셔틀 노선 연결 dead-end 수정

- **Root cause**: `exposureActivated`는 회사/노선 단위, `hasShuttleRouteOverlay`는 공고 단위; 작성 페이지에 `_hasShuttleRouteOverlay` 없음; 정류장 결제 화면이 전부 활성화 시 dead-end
- **Fix**: `ShuttleStopActivationPageResult.overlayLinked`; 결제 화면 「이 공고에 노선 연결」; checkout 후 pop; optional services 패널 콜백·배지·빠른 연결; write/edit/paid pages `_hasShuttleRouteOverlay` 전달
- **Verify**: dart analyze 0 errors on changed files; shuttle tests 11 pass

## 2026-06-18 — A/B 결제 위임 UX 완료

- **A(채용 담당)**: `CorporateJobPostOptionalServicesPanel` — 위임 배너, 버튼·칩 라벨 `exposureActionLabel`, PUSH 이용권은 `payOrRequest`, 일괄 요청 시트
- **B(결제 권한자)**: `CorporatePaymentManagementPage` — 공고 결제 요청 타일에 `requesterDisplayName` 또는 조직 구성원 `displayLabel` 표시
- **Entity**: `JobPostPaymentRequest.requesterDisplayName`; `createRequest` + `CorporatePaymentNavigationHelper`에서 `AuthUser.name` 저장
- **Verify**: analyze 0 errors (3 info); `payment_vault_and_request_test` 2 pass

## 2026-06-17 — 일자리 알림핀 UX + 정류장 표시핀 naming

- **일자리 알림핀**: config (`PushNotificationBasePointPage`) is edit-only — no inline 결제하기; optional services panel splits add row + edit icon like shuttle; new `JobPinActivationPage` + `JobPinActivationService` for map + checkbox payment
- **Naming**: user-visible `정류장 알림핀` → `정류장 표시핀` across `lib/` (optional services, shuttle activation, push ticket use, catalog, exposure_slot_policy)
- **Routes**: `AppRoutes.corporateJobPinActivation`; write/edit pages wire `onNotificationSettingsChanged`
- **Verify**: `flutter analyze` 0 errors; `exposure_slot_policy_test` 5 pass

## 2026-06-17 — PushRadiusMapPicker Naver Map unification

- **Root cause**: `ShuttleStopActivationPage` and all corporate/commute maps used `PushRadiusMapPicker` — a CustomPaint purple-grid MVP; pan blocked when `centerEditable: false`; bottom-left lat/lng overlay always shown
- **Fix**: `_PushRadiusNaverMapPicker` uses `NaverMap` on Android/iOS when configured; mock fallback allows view-only pan via `_viewCenter`; coordinate overlay removed; zoom buttons work on both paths
- **Scope**: shuttle activation, route edit, stop picker, push base point, ticket use, extra push sheet, route preview — all via shared widget
- **Tests**: `push_radius_km_slider_test` updated (no coord text, zoom icon present)

## 2026-06-17 — 이용권 상점 naming & description cleanup

- **Catalog**: `일자리핀`→`일자리`, `PUSH 단독`→`PUSH 이용권`; single-item descriptions aligned with optional services panel; 10회 팩 cards show no description text
- **Shop UI**: `_OfferCard` shows description only for single items with non-empty `marketingLine`; pack10 `cardDetailLine` hidden
- **Tests**: `push_package_catalog_test` updated for 3 sections / 6 SKUs; 8 pass

## 2026-06-15 — 일용직 안내 UX + 고시급 하늘색 핀

- **일용직**: `DailyWorkerPolicy` 안내 다이얼로그(확인 필수), 근무일정·급여 이하 필드 게이트, 급여지급일 근무일+1일 자동·읽기전용; write/edit 페이지 연동
- **지도 핀**: `JobMapPinDisplayTier.premiumWage` (시급 ≥ 11,320원), 하늘색 `0xFF29B6F6`; `MapPinTierResolver` 동적 시급 등급; 랭킹 sponsored 0.45
- **Tests**: `map_pin_tier_resolver_test` 8, `daily_worker_policy_test` 2, 기존 pin tests 6 — 16 pass

## 2026-06-15 — 근태 달력 UX + 쉬운 급여 계산 (MVP)

- **Seeker job detail**: `EasySalaryCalculatorSection` — 시급/일급/월급에서 일·주·월 추정 (`EasySalaryCalculator`)
- **Calendar tabs**: `AttendanceMonthCalendar` on `IndividualWorkTab` + `CorporateAttendanceTab` — status dots, day selection
- **300m proximity**: `AttendanceProximityService` (alert) separate from 200m check-in geofence; banner on seeker 근무 탭; desktop relaxed mode shows prompt
- **Employer**: `EmployerAttendanceHeadcountBanner` + bottom sheet (일용직/그 외); calendar filter menu (전체|일용직|그 외)
- **Tests**: `easy_salary_calculator_test` 6 pass; analyze 0 errors on changed files

## 2026-06-15 — 이용권 상점 redesign (일자리핀·정류장핀 분리)

- **Catalog**: 8 SKUs — `일자리핀` / `정류장핀` (동일 exposure 크레딧), `PUSH 알림권` combo 35,900, `PUSH 단독` 19,900; `ExposureShopVariant` for shop labels only
- **Shop UI**: vertical section list (no tabs); wallet status bar removed; order 일자리핀 → 정류장핀 → PUSH 알림권 → PUSH 단독
- **Tests**: `push_package_catalog_test` 8 pass; `extra_push_availability_test` 3 pass; analyze 0 errors

## 2026-06-15 — Optional services panel copy & PUSH terminology

- **Panel**: `CorporateJobPostOptionalServicesPanel` — section headers `공고는 더 넓게` / `모집은 더 빠르게`; commute title `통근버스 노선 정류장`; push label `알림 (PUSH 보내기)`; removed redundant footer/helper copy
- **App-wide**: Korean `푸시` → `PUSH` in all `lib/` user-facing strings (~120 replacements)
- **Tests**: `extra_push_availability_test` updated; corporate/commute affected tests pass

## 2026-06-15 — AI 공고 가져오기 홈 진입 복원

- **Entry sheet**: `showCorporateCreateJobPostEntrySheet` — 직접 작성 vs AI 가져오기 (no verbose gateway page)
- **Home shell**: `_openCreateJobPost` shows sheet first; import path → `corporateJobPostImport` + job posts tab + snackbar
- **Write page**: AppBar `공고 가져오기` TextButton when `importSourceLabel == null`; import success pops flow result to shell
- **Tests**: `corporate_create_job_post_wizard_test`, `job_post_text_parser_test` — pass

## 2026-06-15 — Billing UX copy audit (3-tier settled)

- **Terminology**: 사업소재지→근무지, 추가 거점/모집지역→일자리 알림핀 across shop, sheets, cards, onboarding, dispatch
- **Routing**: `corporateCreateJobPost` → `CorporateCreateJobPostPage` (import/direct-write gateway)
- **Forms**: edit page mirrors write — `showExposureSection: false` + `CorporateJobPostOptionalServicesPanel` below submit
- **Shop**: header clarifies wallet credit (not instant activation); combo copy uses `exposureEndsLabel`
- **Tests**: wizard route, push_plan_enforcement, extra_push_confirm_sheet — all pass

## 2026-06-15 — Billing compile fixes (3-tier + PushBasePointArgs)

- **Navigation**: extracted `PushBasePointArgs` → `lib/features/corporate/presentation/navigation/push_base_point_args.dart`; updated `app.dart`, write/edit/published pages
- **Base point page**: `_addPointWithCredit` uses `ExposureActivationService.pickCreditMode` + `consumeCredit` (exposure-only vs combo); `_availableCredits` counts both `packageCredits` and `exposurePushBundleCredits`
- **Test fix**: `corporate_attendance_card_test.dart` — required `appliedAt` field
- **Analyze**: 0 errors; push_package_catalog, extra_push_availability, shuttle_overlay_activation tests pass
- **Hot restart required** after `PushPackageBundleOffer.kind` const-class change

## 2026-06-14 — Shuttle overlay paid activation UI

- **Service**: `ShuttleOverlayActivationService` — validates route + not already active, consumes 1 recruitment credit, sets `hasShuttleRouteOverlay: true`
- **Widget**: `ShuttleOverlayActivationSection` — no-route hint / orange activate card / green active state; compact mode for job posts tab
- **Entry points**: `CorporateJobPostPublishedPage`, `CorporateEditJobPostPage` (immediate persist), `CorporateJobPostsTab` (compact banner below card)
- **Copy**: `ShuttleRouteAttachSection` mentions separate paid activation step
- **Tests**: `shuttle_overlay_activation_service_test.dart` — 4 pass (validation + persist)

## 2026-06-14 — Corporate exposure policy (activation ≠ push)

- **Free exposure**: 사업소재지 slot label `현재 노출중` (not `무료`) on 노출 거점 설정 page
- **Shuttle**: `commuteRouteId` registration free; `hasShuttleRouteOverlay` gates seeker map overlay (paid activation)
- **Auto-push removed**: `CorporateJobPostPublishedPage._addNotificationPin` no longer navigates to `corporatePushDispatch`
- **Payment flow**: `PushJobPostPaymentFlow.collect` no longer calls `prepareRegistrationPush`; push only via 공고 탭 「모집하기」
- **Entitlement**: `ShuttleRouteEntitlement.postEligible` requires `hasShuttleRouteOverlay && routeId`
- **Tests**: exposure_point_labels 2 pass, commute_route 8 pass (10 total)

## 2026-06-13 — Daily worker commission + geofence anti-fraud

- **Fee**: 15,000 KRW via `PremiumPartnershipTier.dailyWorkerSuccessFeeKrwMin` (unchanged)
- **Billing trigger**: Mutual **clock-in** only (`seekerCheckedIn` + `employerConfirmed` → `mutuallyConfirmedAt`); `isMutuallyConfirmed` tightened
- **Geofence**: 200m radius (`AttendanceGeofenceService` / `DeviceLocationService.checkInRadiusMeters`)
- **Seeker**: `ShiftCheckInPage` + `QrCheckInPage` — button blocked outside geofence; mock GPS blocked (geolocator `isMocked`)
- **Employer**: `CorporateAttendanceTab._confirmEmployer` — geofence check before `confirmEmployerAttendance`
- **Audit**: `ComplianceRepository.logAttendanceVerification` + abuse flags for mock location / repeated unpaid
- **Side effects**: `MutualAttendanceSideEffects` → commission payment prompt on mutual clock-in
- **Tests**: mutual_attendance 6, attendance_geofence 5, e2e happy path 1 — all pass

## 2026-06-13 — Corporate 서비스 안내 competitive differentiation

- **Cards**: Added 「왜 일jari인가?」「다른 서비스와의 차이」 swipe cards at start of `_cards`
- **Comparison**: Expandable `_ComparisonTable` below page dots — 일반 알바앱 / 동네 알바 / 일jari rows
- **Fees**: `PremiumPartnershipTier.basic.dailyWorkerSuccessFeeKrwMin` (15,000원) for 출근확정 후 수수료 copy
- **Verify**: `dart analyze corporate_service_guide_section.dart` — 0 errors

## 2026-06-13 — Corporate job post labels + map preview navigation

- **Labels**: `corporate_job_post_display_labels.dart` — shared bold labels (소재지·급여·급여 지급일·근무일시), fixes duplicate 시급 prefix
- **Preview**: `CorporateJobPostPreviewPanel` extracted; card + sheet + map overlay reuse
- **Navigation**: 공고보기 → 홈 탭(0) + pin focus + bottom preview panel (not modal)
- **Map**: `CorporateExposureMiniMap` selected pin highlight + centerOnPin; own-pin tap shows preview
- **Analyze**: 0 errors on touched files

## 2026-06-15 — Expired job post workplace reactivation

- **Labels**: `JobPostExposureStatusLabels.workplaceInactive` — 근무지 주변 · 현재 미이용중
- **Use case**: `ReactivateCorporateJobPostUseCase` — postedAt/expiresAt 갱신, status=recruiting
- **Card**: `_ServiceStatusTile` — `post.isExpired` 시 미이용중 + 검은 텍스트·탭 가능
- **Tab**: `corporate_job_posts_tab` — 재등록 확인 AlertDialog(예/아니오), JobBoardRefresh + snackbar
- **Test**: `save_corporate_job_post_usecase_test` reactivate case pass


- **Server**: `job_sync_models.py` — JobPost, Application, ChatMessage, PaymentOrder SQLAlchemy tables
- **Routers**: job_board, hiring, chat_sync migrated from in-memory to DB
- **Payments**: `payment_service.py` — Toss Basic auth fix (base64), checkout URL with client key, confirm + ledger
- **Scraping**: `job_post_scraper.py` — httpx + BeautifulSoup, OG meta, site-specific enrich, rate limit
- **Deploy**: `Dockerfile`, `docker-compose.yml`, `server/.env.example`
- **Flutter**: `RemotePaymentsGatewayService.confirmViaServer`, `PaymentFlowHelper` server confirm path
- **Tests**: `test_job_sync.py`, `test_job_import.py`, `test_payments.py`

## 2026-06-18 — Shuttle overlay link UX clarity

- **Problem**: "이 공고에 노선 연결" immediately showed "노출 중" badge though no payment on this post — company-level stop reuse is correct but UX misleading
- **Panel**: `_ExposureStepBadge` third state `연결 필요`; shuttle badge requires overlay+activated stops for "노출 중"; wallet line "회사 노출 N핀"; info banner + disabled-pay helper; confirm dialog + snackbar on link
- **Activation page**: clearer link-only helper text; snackbar before pop on link success
- **Architecture unchanged**: free link when all stops already `exposureActivated`
- **Verify**: `dart analyze` on 2 files — 0 errors
