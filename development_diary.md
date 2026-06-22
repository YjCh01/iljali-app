# Development Diary

## 2026-06-19 — 지도 근무지 중심 재편 (웹·앱)

- **원인**: 공고에 주소 텍스트만 저장, 좌표 미저장 → 지도·셔틀·핀 기본값(강남) 사용
- **수정**: `CorporateJobPost.workplaceLatitude/Longitude` 저장·지오코딩 fallback
- **지도**: `JobMapPinsDataSource`·`JobPostWorkplaceResolver`·셔틀 노선 등록 시 공고 근무지 좌표 전달
- **PushRadiusMapPicker**: center 변경 시 카메라 재이동 (view-only 포함)

- **원인**: 웹만 별도 JS embed(HtmlElementView) → 빈 화면. 앱은 `daum_postcode_search` HTML WebView.
- **수정**: `web/address_search.html` + iframe + postMessage (앱과 동일 postcode.v2.js)
- **UI**: Daum 노출 문구 제거, 앱과 동일 탭→전체화면「주소 검색」

## 2026-06-21 — 제재 정책 후속 (클라이언트·동기화)

- **sync**: `member_email` — 기업회원 제재 상태 동기화, `exposure_limited` entitlement 반영
- **본인 API**: `GET /v1/sync/member/sanction` — 제재 이력 self-view
- **클라이언트**: 교육 팝업, 보관함 제한, 구직/기업 홈 `MemberSanctionGuard`
- **Admin**: 회원·이용권 탭 **구직자** 목록 + 제재 카드

## 2026-06-21 — 기업 지도 타사 공고 전면 공개

- **변경**: `CorporateMapContentAccessPolicy` — 모든 기업회원이 타사 공고·셔틀 노선 열람 가능
- **제거**: `showCorporateMapIntelPaywall` (주변 채용 정보 유료 유도 다이얼로그)
- **유료핀**: 공고 **홍보/노출**용으로만 유지, 타사 열람 차단과 분리

## 2026-06-21 — Admin 공고 지도 → 네이버 실지도

- **AdminMapPanel**: `CorporateExposureMiniMap`(mock) → `CorporateHomeNaverMap`(앱과 동일 NAVER JS)
- **셔틀**: `CorporateShuttleDensityLoader` + 로컬 노선 repo, 레이어 토글·선택 공고만 필터
- **미리보기**: 유료핀/셔틀 노출 ON·OFF 토글, 지도 모드 배지 (실지도 vs mock fallback)
- **NCP**: localhost:8081 도메인 등록 필요 (`run_admin.sh` → naver 키 전달)

## 2026-06-21 — Admin API 연결 오류 수정

- **원인**: 8000 포트에 **구버전 uvicorn** 이 `/health` 만 응답 → `/stats` 500, `/members/directory/corporate` 404
- **조치**: `run_admin.sh` — stats 성공 여부로 API 준비 판단, stale 시 자동 재시작, 대기 180초
- **확인**: Admin 새로고침 또는 `./run_admin.sh` 재실행

## 2026-06-19 — 제재 정책 (구인자 엄격 / 구직자 관대)

- **정책 카탈로그** (`server/app/services/sanction_policy.py`): 주의·경고·이용제재 3단계, 위반 유형별 tier, 이의제기 7일
- **서비스** (`sanction_service.py`): 정책 적용·해제·이력·기업(company_key) 연동·이용제재 시 공고 숨김
- **API**
  - `GET /v1/admin/ops/sanction/policy`
  - `GET /v1/admin/ops/members/{email}/sanction` — 상태 + 이력
  - `POST /v1/admin/ops/sanction/apply` · `/lift`
  - `POST /v1/hiring/seeker/no-show/sync` — No-show 누적 → 구직자 자동 주의/경고
- **Admin UI**: `AdminSanctionCard` — 위반 유형 선택, tier 조치 미리보기, 적용/해제, 이력
- **클라이언트**: `MemberSanctionStore` — sync bootstrap 제재 상태 저장, `submitApplication` 지원 제한
- **No-show**: `SeekerNoShowBlacklistService` → API 자동 제재 연동
- **테스트**: `server/tests/test_sanction_policy.py` (7 pass with admin_ops)

## 2026-06-21 — Admin Web Console Phase A

- **AdminWebShellPage** — 좌측 네비 + 넓은 화면(900px+) 레일 레이아웃, `/admin` 진입
- **패널 6개**: 대시보드(stats), 기업·이용권, 회원·제재, 공고·핀, QC 시드, 감사 로그
- **서버**: `GET /v1/admin/ops/stats` — seekers/jobs/applications/suspended counts
- **실행**: `run_admin.sh` + `Admin 실행.command` — port 8081, `ADMIN_ENTRY=true`
- **Mac-only dev** 기준; 구인자 앱과 동일 repo `features/admin/`

## 2026-06-21 — 웹 NAVER 지도 로딩 안정화

- **원인**: `run_qc.sh`가 Naver 키 미전달; index.html·Dart 이중 script 로드; 실패 시 무한 스피너
- **수정**: `scripts/naver_flutter_defines.sh` 공통화, run_qc/run_web 모두 `--web-define`+`--dart-define` 전달
- **로더**: bootstrap 12s 대기 → 실패 시 단일 재주입, 30s 타임아웃·에러 표시, JS callback arity 수정

## 2026-06-20 — Mac 웹 실행

- GitHub `main` pull (`59cb1e4`) 후 `flutter run -d chrome --web-port=8080` 로 로컬 웹 기동
- `naver_map_client_id.txt` 없음 → mock 지도 모드 (`NAVER_MAP_NCP_KEY=unset`)
- 주소: http://localhost:8080

## 2026-06-19 — QC·Admin Ops MVP

- **서버**: `/v1/admin/ops/*` (X-Admin-Api-Key) — wallet grant, member sanction, job-pin/shuttle entitlement, seeker 1000 seed, bulk jobs, application distribute, audit log
- **sync**: `/v1/sync/bootstrap` — posts·applications·wallet·member_status
- **Flutter**: `AdminOpsPage` (`/admin/ops`), `QcSyncBootstrap`, `QcAuthService` (seeker-0001@qc.iljari.co.kr / QcTest1234!), `QC_MODE` → mock PG
- **실행**: `run_qc.bat` / `run_qc.sh` — uvicorn + seed 1000 + Chrome
- **fixture**: `server/fixtures/jobs.example.json`, `server/scripts/seed_qc.py`, `scripts/import_qc_jobs.dart`

## 2026-06-19 — 웹 PUSH·정류장 지도 + Mac 실행 스크립트

- **버그**: `/corporate/push-base-point` 등 `PushRadiusMapPicker` 웹 지도 — `NoSuchMethodError: _createWrapper` (빨간 화면). 메인탭 지도는 정상.
- **원인**: Circle/Marker/Polyline 생성 시 `jsify`로 NAVER `Map`·`LatLng` JS 객체를 넘기면 NAVER v3 생성자가 깨짐. PUSH 거점 페이지는 반경 **Circle** 오버레이가 항상 있어서 재현.
- **수정**: `naver_map_web_layer_web.dart` — `callConstructor` + `setProperty` 패턴으로 오버레이 통일; `_syncAllOverlays` try/catch.
- **Mac**: `run_web.sh`, `네이버키_설정.sh` — Windows `run_web.bat` 와 동일 (8080, key 파일, web-define).
- **Verify**: map tests 3 pass

## 2026-06-19 — 웹 주소 검색 Phase 3

- **목표**: Chrome PC 공고 등록 — 근무지 Daum 주소 검색 (Phase 1·2 지도와 함께 웹 co-launch)
- **구현**: `lib/core/address/web/` — `DaumPostcodeWebEmbed` (Kakao Postcode JS v2, `HtmlElementView`)
- **플랫폼**: `WorkplaceAddressPlatform.isPostcodeSupported` (web+mobile), `isQcManualPrimaryMode` (desktop native only)
- **리팩터**: `DaumPostcodeNativeEmbed` (mobile WebView), `DaumPostcodePickerPage` web/native 분기
- **좌표**: 선택 후 `AddressGeocoder.geocode` (Kakao REST, `KAKAO_REST_API_KEY`)
- **Verify**: web build pass; address+map tests 7 pass

## 2026-06-19 — 웹 NAVER 실지도 Phase 2

- **오버레이**: `NaverMapWebCircleSpec`, `NaverMapWebPolylineSpec` — JS Circle/Polyline
- **PUSH·셔틀**: `PushRadiusWebOverlayBuilder`, `_PushRadiusWebMapPicker` (반경 원·드래그 중심·노선)
- **셔틀**: `ShuttleMapWebOverlayBuilder` — 구직자·기업 홈 웹 지도에 정류장·점선 경로
- **버그fix**: `PushRadiusMapPicker` — web에서 native NaverMap 분기 오류 (`shouldUseNativeMap`)
- **Verify**: web build pass; map tests 3 pass

## 2026-06-19 — 웹 NAVER 실지도 Phase 1

- **목표**: Windows/Chrome에서 PC 공고 등록·지도 탐색 — mock → NAVER Maps JS v3
- **구현**: `lib/core/map/web/` — conditional export stub/web, `NaverMapWebWidget`, `JobMapWebMarkerFactory`
- **연동**: `job_seeker_map_view`, `corporate_home_naver_map`, `MapCameraHolder.bindWeb`, `NaverMapPlatform.shouldUseWebMap`
- **실행**: `NAVER_MAP_CLIENT_ID` + NCP Web Dynamic Map 도메인 등록 → `scripts/dev-run.ps1` 또는 `flutter run -d chrome --dart-define=...`
- **Verify**: `flutter build web --dart-define=NAVER_MAP_CLIENT_ID=test` pass
- **Next**: Phase 2 — push_radius_map_picker, 셔틀 폴리라인, Daum 주소 웹

## 2026-06-19 — 공고 탭 노출·알림 서비스 카드 순서

- **변경**: `corporate_post_services_guide` — 알림핀(일자리) → 통근버스(정류장) → 급구알림 순으로 정렬

## 2026-06-19 — 유료 서비스 패널 설정 아이콘

- **변경**: `corporate_job_post_optional_services_panel` `_ConfiguredServiceRow` — 일자리 알림핀·정류장 표시핀 우측 `Icons.edit_outlined` → `Icons.settings_outlined` (추가/저장/수정/삭제 설정 진입)

## 2026-06-19 — Glass Repositories iljali-app 대화 노출 수정

- **원인(2개만 보임)**: Agents > Repositories는 `composer.composerHeaders`가 아니라 **`agentLocation` + `trackedGitRepos.repoUrl`** 로 그룹핑. 125개 중 124개가 `agentLocation: null` → repo 섹션 미노출
- **조치**: `fix-glass-repo-agents.mjs` — 125개에 `agentLocation`(local D:\\1jari) + `repoUrl: github.com/yjch01/iljali-app` + project membership 통합, 프로젝트명 `iljali-app`
- **재실행**: Cursor 완전 종료 → `node scripts/chat-sync/fix-glass-repo-agents.mjs --apply`

## 2026-06-18 — Cursor Agents 대화 iljali-app 재연결

- **원인**: Cursor 3.0 `composer.composerHeaders`가 empty-window·Glass 세션(타임스탬프 workspace)에 묶여 iljali-app repo 목록에 안 보임
- **조치**: `scripts/chat-sync/reindex-iljali-chats.mjs` — 125개 대화를 `D:\1jari` (`cc095c556477ec81d2f10f0fc17d9fa4`)로 retag; `.cursor/chat-archive/index.json` + `index.html` 생성
- **백업**: `%APPDATA%\Cursor\User\globalStorage\state.vscdb.backup-*`
- **재실행**: Cursor 완전 종료 후 `.\scripts\sync-cursor-chats.ps1 -Apply`

## 2026-06-18 — 일자리 알림핀 색상 피커 통일

- **변경**: `push_notification_base_point_page` — `_RecruitmentPinColorPicker`(6색 원형 스와치) 제거 → `ShuttleRouteColorPicker` 재사용 (원형/블록/RGB 세그먼트, HEX 미리보기, 팔레트 팝업)
- **Verify**: `shuttle_route_color_utils_test` pass; analyze 0 errors on changed file

## 2026-06-18 — QA 지도·지갑·알림핀 UX 배치

- **위치 권한**: `MapUserLocationService` + Naver `locationButtonEnable` on corp home, seeker map, push radius picker
- **근무지 중심**: `JobPostWorkplaceResolver`, `workplaceFromJobPost`, job pin maps maxZoom 21, setup purple line removed
- **구직자 알림핀**: `JobRecruitmentMapPinFactory` + seeker solid link on tap
- **corp-alpha 지갑**: dev profile embedded wallet removed; repo seed + ledger pre-claim; load prefers SharedPreferences
- **라벨**: 일자리 알림핀 / 정류장 표시핀; add button always enabled → shop upsell
- **셔틀 편집**: draggable top/bottom panels on `ShuttleRouteEditPage`
- **Verify**: push_wallet + seeder tests pass; analyze 0 errors on changed files

## 2026-06-18 — 황금핀 제거 + 무료 기업 지도 열람 정책

- **황금핀 제거**: `JobMapPinDisplayTier.premiumPartner` 삭제 — 회색·하늘(고시급)·보라(알림핀)만 유지; 100회 팩은 크레딧/할인만
- **기업 지도**: 무료 — 모든 핀·밀도 표시, 타사 공고 내용 차단 + 알림핀 구매 유도; 유료(지갑/레거시) — 경쟁 공고 열람 가능; 자사 공고는 항상 열람
- **Policy**: `CorporateMapContentAccessPolicy`, `showCorporateMapIntelPaywall`
- **Verify**: 25 tests pass (pin tier, ranking, visual theme, map access)

## 2026-06-18 — 기업 홈 셔틀 밀도 오버레이

- **Feature**: `CorporateShuttleDensityLoader` — 구직자 노출 기준(overlay post + activated stops)으로 전사 셔틀 정류장·폴리라인 표시
- **Maps**: `corporate_home_map_background`, `corporate_home_naver_map`, `corporate_exposure_mini_map`, `corporate_home_exposure_map`
- **Tap**: 경쟁 정류장 → `showCorporateMapIntelPaywall`; 자사 노선은 스낵바; `CommuteRouteRepository.loadAllActive`
- **Verify**: shuttle density + map access tests 9 pass

## 2026-06-18 — Android 개발 테스트 로그인 크래시

- **Root cause**: `LocalHiringRepository.create()` → `fetchAll()` → `HiringApplication.fromJson` — legacy SharedPreferences에 `status: "approved"` 등 invalid enum → `ArgumentError` → dev login red screen
- **Fix**: safe enum parsing in `HiringApplication.fromJson`; skip corrupt rows in `fetchAll`; SnackBar in `DevTestLoginPanel`; gateway scrollable (dev panel overflow)
- **Build**: `build_apk_debug.bat` — reads `naver.map.client.id` from `android/local.properties` → `--dart-define`
- **Verify**: corrupt prefs test + gateway + dev seeder tests pass; analyze 0 errors

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

## 2026-06-19 — Admin dashboard API fetch fix

- **Problem**: `ClientException: Failed to fetch` on `/v1/admin/ops/health` — CORS blocked Flutter web (8081) → API (8000); sidebar falsely showed "API 연결됨" from dart-define only
- **Server CORS**: `main.py` — explicit localhost origins + regex; `allow_credentials=False`; filter `*` from origins list; updated `config.py` default + `server/.env`
- **Client**: `AdminOpsController.apiConnected` from real health check; sidebar shows red when fetch fails
- **Scripts**: `run_admin.sh` — `localhost:8000`, stale-port restart, `wait_for_api` curl loop; `run_qc.sh` same localhost URL

## 2026-06-19 — Admin map + chat moderation viewer

- **공고 지도** (`AdminNavSection.map`): `GET /v1/admin/ops/jobs/map` + `AdminMapPanel` — `CorporateExposureMiniMap` read-only 탐색, 핀 선택 시 상세·유료핀 토글
- **채팅 열람** (`AdminNavSection.chat`): 회원 검색 → 지원 목록 → `GET /v1/admin/ops/applications/{id}/chat` 전체 메시지 (구인·구직·시스템)
- **API**: `list_jobs_for_map`, `list_applications_for_admin`, `list_chat_for_application` in admin_ops_service; member search extended to display_name/company_name
- **Client**: `AdminOpsApiClient.listMapJobs/listApplications/getApplicationChat`, `AdminMapPinFactory`

## 2026-06-19 — run_admin uvicorn fix (Mac)

- **Problem**: `uvicorn: command not found` — Python venv not set up on Mac
- **Fix**: `scripts/server_dev.sh` — auto-create `server/.venv`, `pip install -r requirements.txt`, run `python -m uvicorn`
- **Updated**: `run_admin.sh`, `run_qc.sh`; added `server/.venv/` to `.gitignore`

## 2026-06-19 — Admin map empty fix

- **Cause**: Admin launch did not seed jobs — map API returned 0 posts; UI hid map widget when empty
- **Fix**: `iljari_admin_ensure_sample_jobs` on Admin start; map always renders grid + overlay; "샘플 공고 불러오기" button; `seed_qc.py` wallet print bug

## 2026-06-19 — Admin member directory (기업·구인자)

- **기업회원 탭**: 사업자번호(BRN)별 폴더 → 결제관리자/본사관리자/지점관리자/채용담당 하위 트리
- **구인자회원 탭**: 전체 구인자 flat 목록
- **정렬**: 기업=사업자번호·ㄱㄴㄷ·가입순 / 구인자=가입·이름·기업명·BRN
- **검색**: 이름·전화·이메일·사업자번호·지점·부서
- **Server**: QcMemberRow +phone/org_role/branch_name; `GET /members/directory/corporate|employers`; `seed_employers`

## 2026-06-19 — Admin map post detail (poster · views · applications)

- **가능/구현**: 공고 지도 핀 선택 시 등록자·열람·지원 상세 표시
- **DB**: `job_posts.posted_by_*`, `view_count`, `map_impression_count`
- **API**: `GET /v1/admin/ops/jobs/map/{id}`, `POST /v1/job-board/posts/{id}/view` (앱 상세 열람 시 +1)
- **Admin UI**: 등록자(이름·역할·이메일·전화), 성과(열람·지도노출·지원·상태별), 최근 지원자 10명

## 2026-06-19 — Admin 회원·이용권 탭 통합

- **의견 반영**: 기업·이용권 / 회원·제재 분리 탭 폐기 → **회원·이용권** 단일 탭
- **좌측**: 기업회원·구인자회원 검색/열람 (기존)
- **우측**: 기업 선택 → 이용권 부여·잔액 / 구인자 선택 → 제재 + 동일 기업 이용권
- **삭제**: `admin_wallet_panel.dart`, 사이드바 `기업·이용권` 메뉴

## 2026-06-19 — 기업 미인증 가입 (신규 사업장)

- **방향**: 국세청 미조회·신규 사업장 → **미인증(pending)** 가입 허용 → **무료 공고** / 등록증 승인 후 **유료 서비스**
- **가입 UI**: 검증 단계 `국세청 미조회 · 미인증 회원으로 가입` 버튼, NTS 실패 시 안내
- **정책**: `CorporateVerificationAccessPolicy` — pending=무료 공고 OK, paid blocked
- **서비스**: `registerProvisionalBusiness`, `submitCertificateForReview`
- **게이트**: `PushPackagePurchaseService`, `JobPinActivationService` 유료 차단
- **내정보**: 미인증 배너 + 사업자등록증 제출 → adminReviewRequired → Admin 승인 시 verified 승격


## 2026-06-19 — 결여사항 마무리 (구직·구인·어드민)

- **구직자**: 6탭→5탭(내 일=지원+근무), PUSH→채팅 버그, 접수중 지원 표시, 지도 코치, 길찾기(Naver)
- **구인자**: `CorporateWebScaffold`(웹 900px+), `AdaptiveSheet`, 공고 서버 push, 웹 결제 callback URL
- **어드민**: 회원·이용권 패널에 `AdminCompanyVerificationCard` (등록증 승인)

## 2026-06-19 — 노출 연장(체크박스) + 보유금 충전

- **연장 UX**: D+1 23:59:59 만료·임박 핀·정류장을 알림핀/표시핀 결제와 동일한 체크박스 UI로 선택 → 이용권·보유금·PG 순 차감 후 `exposurePaidAt` 갱신
- **채팅 탭**: `officialNotice` 방 — 「일자리 공식 알림」→ 예(연장하기) / 아니오(나중에)
- **보유금**: `EmployerPushWallet.cashBalanceKrw` · `/corporate/cash-charge` · 결제 시 `PaymentFlowHelper` 우선 차감
- **테스트**: `exposure_renewal_policy_test.dart` 5건 통과

## 2026-06-19 — 출시 로드맵 6단계 진행 (0~6)

### Stage 0 — 환경
- `run_seeker_qc.sh`, `run_corporate_web.sh`, `LAUNCH_ROADMAP.md`

### Stage 2 — 구직자 QC
- 지원 `createApplication` 서버 sync
- 공고 `workplace_latitude/longitude` + bootstrap hydrate
- 보관함 `showKoreanDatePickerSheet`

### Stage 3 — 인프라
- `/v1/auth/login|me|phone/send|verify` + Bearer in `IljariApiClient`
- `AuthSession.accessToken`, QC seeker 서버 로그인
- `PhoneVerificationService` API 연동
- `server/tests/test_auth.py` 2건

### Stage 4 — 구인자 웹
- AdaptiveSheet: push_ticket / extra_push / payment_request

### Stage 5 — 컴플라이언스
- `REQUIRE_NTS_API_KEY` — mock 차단

### Stage 6
- metrics 레거시 tier 제거 → 패키지 단가 기준

## 2026-06-22 — AdaptiveSheet 전체 마이그레이션 (Stage 4)

- **판단**: Staging HTTPS보다 로컬 검증 가능한 UI 마이그레이션을 우선 (구인자 웹 안정성)
- **변경**: `lib/` 내 `showModalBottomSheet` 직접 호출 **전부** → `showAdaptiveSheet` (모바일 bottom sheet / 웹 900px+ 우측 패널)
- **범위**: 구인자 공고·결제·PUSH·근무일정·셔틀·채팅 매크로 + 공통 `korean_calendar`·`scroll_time_picker` + 구직자 지원·보관함
- **검증**: `individual_home_shell_test`, `work_schedule_codec_test`, `work_date_range_picker_field_test` 통과

## 2026-06-22 — Staging HTTPS (Stage 3)

- **스택**: `docker-compose.staging.yml` — Postgres + API (internal) + nginx :443
- **TLS**: `scripts/staging/init-certs.sh` self-signed (로컬) · 실서버는 certbot으로 `server/staging/certs/` 교체
- **nginx**: `server/nginx/staging.conf.template` → `staging/nginx.generated.conf` (API proxy + Flutter SPA)
- **실행**: `./run_staging.sh` — web build, compose up, QC seed
- **env**: `server/staging/env.example` → `server/.env.staging` (CORS·결제 redirect·Toss webhook URL)
- **서버**: `ProxyHeadersMiddleware` (nginx X-Forwarded-Proto)

## 2026-06-22 — 로드맵 Stage 5~6 밀어붙이기

- **OCR↔BRN**: `ocr_business_cross_check` (Dart+Python) — provisional·cert 제출·서버 verify 교차검증
- **약관 버전**: `LegalConsentCatalog` + seeker/corporate 프로필 `*VersionAccepted` + 가입 UI 링크
- **Aligo SMS**: `aligo_sms_service.py` + `phone_verify_service` rate limit
- **bundle ID**: `kr.co.iljari.app` (Android/iOS/macOS/Linux)
- **모니터링**: `error_reporting.dart` + `SENTRY_DSN` dart-define 훅
- **certbot**: `scripts/staging/certbot-init.sh`

## 2026-06-22 — 출시 마감 일괄 (Stage 6·3)

- **Sentry**: `sentry_flutter` + `initializeErrorReporting`
- **웹 결제**: `/payment-success` · `/payment-fail` + `PaymentWebCallbackPage` + path URL strategy
- **약관 재동의**: `LegalConsentGate` + 전자금융거래 탭
- **Toss E2E**: `test_toss_e2e.sh`, `test_payment_webhook.py`, `test_payments_toss_config.py`
- **스토어**: `store/README.md`, `fastlane/Fastfile`, `scripts/build_release.sh`

## 2026-06-22 — 약관·정책 초안 전체 + PDF

- **문서 9종**: `store/legal/01~09_*.md` (알바몬·사람인·당근·토스·KISA 등 참고 재구성)
- **형광펜 마커**: `[[REVIEW:...]]...[[/REVIEW]]` → 앱 `LegalHighlightedText` + PDF 노란 배경
- **앱 연동**: `LegalDocumentCatalog` + `assets/legal/` + 약관 페이지 9탭 스크롤
- **기업 가입**: 아웃소싱 약관 전문 asset 로드 + 형광펜
- **PDF**: `dart run tool/generate_legal_pdfs.dart` → `store/legal/pdf/*.pdf` (9개)
- **주의**: 초안이며 변호사 검토 전 — REVIEW 구간 수정 필수

## 2026-06-22 — 약관 사업자명·서비스명 확정

- **사업자명**: 아라컴퍼니 · **서비스명**: 일자리 — 9종 약관 전반 반영
- **형광펜 유지**: 사업자등록번호·대표·주소·시행일·단가·관할법원 등 [[REVIEW]] 구간
- PDF·assets 재생성

## 2026-06-22 — 사업자 정보 확정

- 사업자등록번호 540-31-00894, 대표 최영진, 송파구 본점 주소 반영
- 관할: 서울동부지방법원 (본점 소재지)
- 개인정보·위치정보 책임자: 최영진

## 2026-06-22 — 고객센터 연락처 확정

- 이메일(우선) aracorp22@naver.com · 전화 +8210-9742-1214
- 위치기반서비스 신고: 진행 중 문구 + 신고번호만 형광펜
- 앱 고객센터 페이지 동기화

## 2026-06-22 — 출시 로드맵 잔여 (스토어·사업자 표시)

- `BusinessDisclosure` + 더보기/고객센터 사업자 정보 푸터 (전자상거래법)
- `store/listing/` Play·App Store 등록 텍스트
- `scripts/store_preflight.sh` — 번들 ID·약관·AAB 점검
- `fastlane/Appfile` + README
- certbot 기본 이메일 aracorp22@naver.com

## 2026-06-22 — 웹 우측 네비게이션 (메인 탭)

- `WebRightNavigationRail` + `WebLayoutBreakpoints` (900px, AdaptiveSheet와 동일)
- 구인자: `CorporateWebScaffold` 레일 **좌→우** 이동
- 구직자: `IndividualWebScaffold` — 웹 넓은 화면에서 하단 탭 → 우측 레일
- 앱·좁은 웹: 기존 하단 탭 유지

## 2026-06-19 — 지도+설정 패널 웹 우측 분할

- `MapFormSplitLayout` / `MapStackSplitLayout` — 900px+ 웹: 지도 좌 · 설정·목록·결제 우(480px)
- 적용: `push_notification_base_point_page`, `job_pin_activation_page`, `exposure_renewal_page`
- 셔틀·정류장: `shuttle_route_edit_page`, `shuttle_stop_payment_page`, `push_ticket_use_page`
- 모바일: 기존 상하 스택 유지

## 2026-06-19 — 마감유령핀 (closed ghost pins)

- 만료·마감된 **무료(standard) 공고** → 회색 마감유령핀으로 지도 유지
- 탭 시 `마감된 공고입니다.`만 표시 (상세·지원 불가)
- Admin 공고 지도: **마감유령핀 배치** 모드 + 서버 CRUD (`closed_ghost_pins`)
- QC bootstrap `ghost_pins` 동기화

## 2026-06-19 — 광고그리드(60초 릴스) 임시 제거

- 「기존의 끝없는 비용 출혈」 파란 카드만 제거
- 「공고를 등록하면!」 보라 안내 카드는 더보기 탭에 유지

## 2026-06-19 — 지도 기본 축척 100m 통일

- `MapConstants.scale100mZoom = 17` (Naver Maps 서울 기준 ~100m 축척)
- `defaultZoom` / `warehouseAreaZoom` / `PushRadiusMapPicker.mapZoom` 기본값 통일
- 내 위치 이동·mock·기업 홈 지도 초기 줌 동기화
