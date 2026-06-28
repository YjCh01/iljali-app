- **고객센터 이메일**: iljariapp@gmail.com (`BusinessDisclosure` · 약관 · 스토어 listing)

## 2026-06-28 — 기업 공고 목록 타사 노출 차단 (보안)

- **원인** in-memory 공고 풀 전체를 `GetCorporateJobPostsUseCase`가 그대로 반환
- **수정** `CorporateJobPostScope` · companyKey 필터 · 수정/삭제 소유권 검증 · API PUT/DELETE 인증

## 2026-06-28 — 대화방 나가기 (구직자·기업)

- 채팅 목록 ⋮ 메뉴 + 채팅 화면 햄버거 메뉴 → `대화방 나가기`
- 확인 다이얼로그 후 목록에서만 숨김 (`ChatRoomLeaveService`, 사용자별 localStorage)
- 지원·채용 상태는 유지 (지원 취소와 별개)

## 2026-06-28 — 채팅 목록 중복 (로컬+서버 지원 ID)

- **원인** 지원 시 로컬 `app_{timestamp}` + 서버 sync `app_{uuid}` 각각 저장 · 배포와 무관(localStorage 유지)
- **수정** `mergeServerApplication` · `dedupeActiveApplicationsForSeeker` · 서버 POST 중복 방지


- **사유** 개인 앙심 기반 평점·신뢰 점수는 신뢰성 낮음
- **MVP** `ENABLE_EMPLOYER_TRUST_DISPLAY=false` — 공고 상세 별점·신뢰100·우수 고용주 배지 숨김
- **페이즈 2** 구직자 평점(어드민 전용)·고용주 평가 다이얼로그 — `ENABLE_SEEKER_EMPLOYER_RATING`


- **요청** 채용 확정 전 구직자 채팅에 「근무예정 합의하기」 노출 금지 · 출근·수수료 플로우 제거
- **플로우** 공고 업로드 → 지원 → 기업 이력서 열람·채팅 (채용 여부는 기업 자율)
- **구현** `ENABLE_HIRING_COMMISSION=false`(기본) 시 합의 UI·instantAccept·출근 잠금 비활성 · 테스트 `hiring_mvp_apply_chat_test.dart`


- **기존** `도구_실서비스한방배포.command` → API + 웹만
- **변경** ③ App — AAB + APK + iOS(no codesign) · Play/TestFlight credentials 있으면 fastlane 자동 업로드
- **옵션** `--no-app`(웹만) · `--app-only` · `--store-upload`(업로드 실패 시 exit 1)


- **요청** 지원 시 기업이 등록한 달력(일용·단기·계약·정규) 그대로 표시 · 교대 선택 제거
- **일용·단기** `근무일자 선택(중복가능)` + `모든날짜 선택하기`
- **계약·정규** `근무 시작 희망일` 단일 선택
- **구현** `WorkScheduleCalendarView` · `WorkScheduleCalendarX` · `SelectedShiftDates`(복수 ISO 쉼표) · `job_apply_flow_sheet` 개편


- **문제** 지원 시 일반 온보딩(여기까지 저장하기)으로 빠짐 → 저장 후 공고로 복귀·지원 재개 안 됨
- **수정** `forJobApply` 모드 — 필수 4단계 후 「완료하고 지원하기」·하단 저장 그리드 숨김 · 프로필 완료 시 `showJobApplyDialog` 자동 재개

## 2026-06-28 — 구직자 프로필 로그인 시 초기화 수정

- **원인** 서버 로그인 응답의 빈 `seeker_profile`이 로컬(SharedPreferences)에 저장된 이력서·온보딩 데이터를 덮어씀 → 재로그인 후 지원 불가·빈 프로필 폼
- **수정** `SeekerProfileMerge` 로컬·서버 병합 · `SeekerProfileSyncService` 저장 시 서버 `PATCH /v1/auth/me/seeker-profile` · 온보딩 저장도 동기화

## 2026-06-28 — 자격증 열람·다운로드 (채용 확정 후)

- **규칙** 채용 확정(`isMutuallyConfirmed` / `commissionPaid`) 전 — 기업은 **보유 여부·이름만** · 확정 후 **원본 열람·다운로드**
- **구현** `HiringCredentialAccess` · `EmployerVisibleCredential` · `EmployerCredentialSection` · `SeekerCredentialViewerPage` · 지원 시 `requiredCredentialIds` 스냅샷 · 필수 자격 미등록 시 지원 차단

## 2026-06-28 — 지원하기 프로필 게이트·완료 안내

- **원인** `isMatchingReady`가 `onboardingCompletedAt`만 검사 → 「여기까지 저장하기」만 한 경우 지원 불가(스낵바만 표시)
- **수정** 필수 필드(이름·주민번호·실주소·지역·스케줄) 기준 검사 · 미입력 항목 다이얼로그 · 지원 성공 **「지원 완료」** 다이얼로그 · 부분 저장 시 필드 충족하면 자동 완료 처리

## 2026-06-28 — 프로필 온보딩 부분 저장·취소

- **문제** 「나중에 하기」가 저장 없이 pop → 입력 전부 소실
- **수정** `SeekerProfileOnboardingFlow` — `initState` 기존 프로필 hydrate · **여기까지 저장하기** (`_saveProgress`, `onboardingCompletedAt` 미설정) · **취소하기** (저장 없이 닫기) · 하단 2열 그리드 타일

## 2026-06-19 — 개인회원 2단계 가입

- **1단계** `IndividualSignUpFlow` — 휴대폰 본인인증(SMS OTP, 추후 다날) → 이메일(아이디)·비밀번호·약관 → 가입 후 **지도 열람**
- **2단계** `SeekerProfileOnboardingFlow` — 이름·주민번호·실주소·희망지역·스케줄·사진 → `onboardingCompletedAt` 후 **지원 가능**
- **게이트** `seeker_profile_readiness` — 지원 시 미완성이면 SnackBar + 프로필 완성 유도; 더보기 탭 배너
- **테스트** `PhoneVerificationService.localMock()` 주입 · `individual_sign_up_flow_test` · `individual_home_shell_test` UI 문구 정리

## 2026-06-28 — 어드민 기업 등록증 승인 (라인헬스케어 fallback)

- **원인** 실서버 `GET /v1/admin/ops/companies/{brn}/verification` **404 미배포** → 어드민이 브라우저 SharedPreferences만 조회. 아라컴퍼니만 로컬 기록 있음.
- **수정** `AdminCompanyVerificationCard` — ops 실패 시 `business-records` → qc_members(`registeredOnServer`) → 승인은 ops 또는 **`PATCH /v1/admin/companies/{brn}/review`** fallback
- **배포** admin 웹 + API (`deploy_prod_all.sh`) 필요

## 2026-06-28 — 배포 health 502 오탐 수정

- **원인** API 컨테이너 재시작 직후 nginx edge가 upstream 미준비 → 502. 배포 스크립트가 3초만 대기 후 1회 curl.
- **현재** API는 정상(200). site/admin 웹도 200.
- **수정** `iljari_remote_api_wait_block` + `iljari_verify_public_api_health`(90s retry) — `deploy_prod_all.sh`, `deploy_server_api.sh`

## 2026-06-28 — 지원 전 공고 문의 채팅

- **상태** `HiringApplicationStatus.inquiry` — 지원 전 문의 전용
- **흐름** 공고 상세 「문의하기」→ 채팅방 생성·재진입 (로그인만 필요, 프로필 완성 불필요)
- **지원** 문의 후 지원 시 inquiry → applied 승격 (중복 지원 아님)

## 2026-06-28 — 개인 로그인 진단·폴백

- **원인 후보** ① 서버 미가입(로컬만) ② 기업회원 이메일로 개인 로그인 ③ QC 레거시(비번 미설정)
- **수정** `IndividualAuthRepository` — member_type 검사, 서버 401 시 로컬 계정 폴백, 안내 문구
- **도구** `scripts/diagnose_member_login.sh <email>` · 어드민 members `has_password`

## 2026-06-28 — 희망 근무지역 «실주소 지역 추가»

- **원인** 주소 API가 `경기 용인시…` 약칭 반환 — 파서는 `경기도`만 인식 → GPS fallback → 실패
- **수정** `SeekerRegionFromAddress` 약칭 시·도 지원 · GPS 버튼 제거 → **실주소 지역 추가**

## 2026-06-19 — 실서비스 한방 배포

- **`도구_실서비스한방배포.command`** → `scripts/deploy_prod_all.sh`
- API + site + admin 순서, SSH 세션 1회 (비밀번호 1번)
- 옵션: `--api-only` · `--web-only`

## 2026-06-19 — 공고 본문 이미지·HTML

- **본문 모델** `JobPostDescriptionBody` — text · images · html (제목·급여·일정과 분리)
- **작성 UI** `JobPostDescriptionBodyEditor` — 글/이미지/HTML 탭 (WYSIWYG 없음)
- **표시** `JobPostDescriptionBodyView` — 상세·미리보기 동일 스타일, 이미지 핀치 줌
- **API** `POST /v1/job-media/upload` + `description_body_json` DB 컬럼 + sync
- **콜아웃** 이미지/HTML-only 본문은 snippet 비움 — 제목·급여·일정 그리드는 기존 필드

## 2026-06-19 — 계약직 고용형태 · 근무기간(시작·종료)

- **플래그** `ENABLE_WORKER_CONTRACT` 기본값 `true` — 공고 작성 폼·위저드에 **계약직** 탭 노출
- **근무기간** `WorkerCategory.usesWorkPeriodWithEndDate` — 계약직은 정규직과 달리 **시작일+종료일** 필수 (달력 2탭)
- **검증** 공고 등록·수정·`SaveCorporateJobPostUseCase` — 미완료 기간 시 「근무 시작일과 종료일을 선택해 주세요.」
- **테스트** `product_feature_flags_test` · `worker_category_test`

## 2026-06-19 — 친구 테스트 DB 누적 (기업 인증·게스트 공고·채팅 동기화)

- **서버** `POST /v1/auth/signup/corporate` — 기업 회원 DB 영속 (company_key·handler_code·비밀번호)
- **Flutter** `CorporateAuthRepository` — 기업 가입/로그인 서버 연동 (다른 기기 재로그인 가능)
- **게스트** `QcSyncBootstrap.pullPublicCatalogIfEnabled` — 비로그인도 서버 공고·고스트핀 pull (`main`·지도 탭)
- **채팅** `ApplicationChatMessageRepository.loadSynced` — 서버 `/v1/chat-sync` ↔ 로컬 캐시 양방향
- **DB** `qc_members.contact_person_name` 컬럼 + PostgreSQL idempotent migrate
- **배포** `scripts/deploy_server_api.sh` — API tar + docker rebuild; `deploy_all_prod_web` site/corporate/admin 실서버 반영 (2026-06-26)

## 2026-06-26 — 개인 가입 UX (희망업무 제거·스케줄·가입 오류)

- **희망업무** 가입 단계 삭제 — `individual_sign_up_flow` 8단계
- **근무 스케줄** 24h 시계(30분)·요일 중복·야간 익일 표시 `금 21:00–07:00 (토)`
- **매칭 베이스** `SeekerAvailabilityMatcher` — 페이즈2 푸시 시간대 overlap
- **가입 오류** 휴대폰 인증 토큰 TTL 10분→60분; `workAvailability` JSON 배열; 로컬 사진 경로 서버 미전송

## 2026-06-19 — 사업자 정보 변경 (언리얼리)

- **상호**: 아라컴퍼니 → **언리얼리**
- **사업자등록번호**: 537-58-01045 · **대표**: 최영진
- **주소**: 경기도 용인시 수지구 용구대로 66, 205-202
- `BusinessDisclosure` SSOT · `assets/legal` · `store/legal` 9종 동기화
- 약관·개인정보 버전 `2026-06-19` (재동의 게이트)

## 2026-06-19 — 인재 검색 · 채용 제안 (런치 MVP)

- **도메인**: `JobProposal` / `JobProposalRepository` (pending·accepted·declined)
- **인재 풀**: `SeekerTalentDirectory` — DevTest·로컬 가입·현재 세션 집계, 이름 마스킹
- **검색**: `TalentSearchService` — 자격·희망지역·출근 요일 필터, `proposalOffersAccepted` opt-in
- **프로필**: `SeekerMemberProfile.proposalOffersAccepted` (기본 true), 더보기 탭 토글
- **기업 UI**: 지원자 탭 → 인재 검색 카드, `CorporateTalentSearchPage`, `send_job_proposal_sheet` (활성 공고 필수)
- **구직 UI**: 지원 현황 상단 「받은 채용 제안」, 수락 시 기존 지원·셔틀·이력서 공개 플로우 합류
- **라우트**: `AppRoutes.corporateTalentSearch`
- **QC 시드**: seeker-alpha/beta에 자격·요일 샘플 데이터

## 2026-06-19 — 정규직 고용 형태 (웹·앱 공통)

- **WorkerCategory.regular** — 고용 형태 칩·위저드에 「정규직」 추가 (기본 활성)
- **근무 일정**: 요일고정/교대순환/날짜맞춤·근무요일 체크 유지, 근무기간은 **첫 근무 시작일**만
- **협의가능**: 일정 시트 하단 체크 — 시작일 선택 여부와 독립적으로 교차 선택
- **급여지급일**: 당월 1~31일 / 익월 1~31일 중 하나 (`_MonthlyPaymentDayField`)
- **저장**: `workPeriodNegotiable` + `정규·` 접두 workSchedule 코덱
- **테스트**: `work_schedule_codec_test`, `product_feature_flags_test` 통과
- **버그픽스**: 정규직 일정 적용 후 폼 미리보기 `endDate!` null 크래시 → `work_schedule_field_preview.dart` 첫 근무 시작일 전용 표시

## 2026-06-23 — 브랜드 광고 카피 배치 (앱·웹)

- **카피**: 「내 근처에서 찾고, / 우리집 앞에서 타고. / 내 주변 일자리!」
- **공통**: `lib/core/branding/iljari_ad_campaign.dart` (`IljariAdCampaignCopy`, `IljariAdCampaignBanner`, `IljariAppLoadingView`)
- **로딩**: 홈 분기·구직 지도 초기 로딩, `web/index.html` Flutter 부트스트랩 스플래시
- **로그인**: 게이트웨이·`AuthScaffold`(이메일 로그인 상단)
- **더보기**: 구직자·기업 탭 상단 그라데이션 배너


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

## 2026-06-19 — 구직자 실주소 지도 중심 + 위치동의 재확인

- `SeekerMemberProfile` — `homeRoadAddress`·좌표·`locationConsent` 필드
- `SeekerHomeAddressResolver` — 실주소 지오코딩 → 구직자 지도 초기 중심
- `LocationConsentService` — 가입·출근체크·지도에서 앱 동의 + 기기 GPS/권한 매번 재확인
- 가입 플로우 `실주소` 단계, 더보기「실주소」, 출근체크·QR 출근 게이트

## 2026-06-19 — QC 눈검증 (알파 + QC구직자 0001)

- **시나리오 시드**: `seed_qc_visual_scenario` — `qc_post_real_001` + `seeker-0001` 지원·채팅
- **클라이언트**: `QcVisualScenarioSeeder` — 로그인 후 지원(scheduled)·채팅·보관함·출근 탭 데이터
- **실행**: `./run_dual_qc.sh` — 구직자 8082 + 기업 8081 동시 Chrome

## 2026-06-19 — 자격증 UI 정리 + 고객센터 전화번호 임시 교체

- **자격·면허 UI**: 사진 필수 항목에서 체크박스 제거 — 업로드 버튼만으로 보유 등록 (체크박스·업로드가 동일 동작이던 중복 해소)
- **전화번호**: 앱/웹 전역 `+8210-9742-1214` → `1566-0000` (`BusinessDisclosure`, 약관 md, 고객센터)


- **사업자명**: 아라컴퍼니 · **서비스명**: 일자리 — 9종 약관 전반 반영
- **형광펜 유지**: 사업자등록번호·대표·주소·시행일·단가·관할법원 등 [[REVIEW]] 구간
- PDF·assets 재생성

## 2026-06-22 — 사업자 정보 확정

- 사업자등록번호 540-31-00894, 대표 최영진, 송파구 본점 주소 반영
- 관할: 서울동부지방법원 (본점 소재지)
- 개인정보·위치정보 책임자: 최영진

## 2026-06-22 — 고객센터 연락처 확정

- 이메일(우선) iljariapp@gmail.com · 전화 1566-0000
- 위치기반서비스 신고: 진행 중 문구 + 신고번호만 형광펜
- 앱 고객센터 페이지 동기화

## 2026-06-22 — 출시 로드맵 잔여 (스토어·사업자 표시)

- `BusinessDisclosure` + 더보기/고객센터 사업자 정보 푸터 (전자상거래법)
- `store/listing/` Play·App Store 등록 텍스트
- `scripts/store_preflight.sh` — 번들 ID·약관·AAB 점검
- `fastlane/Appfile` + README
- certbot 기본 이메일 iljariapp@gmail.com

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

## 2026-06-19 — GitHub push 인증 (HTTPS → SSH)

- 원인: GitHub는 계정 비밀번호로 `git push` 불가 (PAT 또는 SSH 필요)
- `origin`을 `git@github.com:YjCh01/iljali-app.git`으로 변경
- SSH 키(`~/.ssh/id_ed25519`)로 `main` push 완료: `e543da1..c601c02`

## 2026-06-23 — 알림핀 설정 지도 근무지 중심 보정

- 원인: 저장된 0번 거점 좌표가 강남 기본값인데 주소만 근무지(용인 등)로 바뀐 레거시 데이터
- `_resolveWorkplaceCenterIfNeeded`가 `initialSettings` 있으면 지오코딩을 건너뜀
- 이전 세션 뷰포트(강남)가 근무지 고정 모드에서 카메라를 덮어씀
- 수정: 주소·좌표 불일치 시 지오코딩 후 0번 거점·카메라 갱신, stale viewport 무시
- 서버: Kakao 주소 API로 전체 도로명 직접 지오코딩 fallback

## 2026-06-23 — 근무지 지도 중심 (근본 수정)

- **실제 원인**: `server/.env`에 Kakao/JUSO 키 없음 → 지오코딩 실패 → `WorkplaceAddressQc.sampleCoordinate`(강남)으로 저장
- 주소 선택 시 강남 샘플 좌표 fallback **제거** (좌표 null 허용)
- 웹: **NAVER Maps JS Geocoder** (`submodules=geocoder`) — 지도 Client ID로 좌표 변환
- 서버: `GET /v1/addresses/geocode` 추가
- 알림핀 설정: 주소 기준 항상 지오코딩 후 0번 거점·카메라 동기화

## 2026-06-23 — 앱 지오코딩 (웹과 동일 동작)

- `AddressGeocoder`: 서버 실패 시 **웹=Naver JS** · **앱=iOS/Android Geocoder** (`geocoding` 패키지)
- `map_backed_address_geocoder_{web,io}` — Kakao/JUSO 키 없이도 근무지 좌표 확보
- `./run_app.sh` — API 서버 + `COMPLIANCE_API_URL` + Naver dart-define 자동 주입

## 2026-06-23 — 핀·PUSH 반경 1km → 700m

- `PushPackageCatalog.freePushRadiusM` / `packagePushRadiusM` = 700
- `pushRadiusLabel` = `700m` — 지도 원·PUSH 도달·안내 문구 전역 동기화

## 2026-06-19 — 구직자 QC 점검 (웹/앱)

### 자동 검증
- `flutter test test/features/job_seeker` + hiring/chat 정책 테스트 통과
- `flutter build web` 성공
- 서버 pytest: 21 passed, 1 failed (`test_seed_seekers_and_sanction`)
- hiring E2E·회원가입 테스트 4건 기대값 불일치 (수수료 플로우/UI 문구)

### QC 전 수정 (웹 블로커)
- `seeker_my_documents_page` — 웹 `dart:io` 제거, base64 data URL 저장
- `chat_message_bubble` — 첨부 미리보기/뷰어 웹 호환
- `application_chat_page` — 사진 전송 시 웹 persist

### 수동 QC
Finder **`개인회원 실행.command`** (8082, 개인회원 로그인 직행) 또는 `./run_seeker_web.sh` — `seeker-0001@qc.iljari.co.kr` / `QcTest1234!`

### 알려진 MVP 한계
- QR 스캔·소셜 로그인 "준비 중", PUSH 인박스 로컬만, 보관함 캘린더 스텁

## 2026-06-19 — 개인회원 지도 우선·탭/더보기 정리

- **최초 화면**: 비로그인도 `RoleBasedHomePage` → 구직 지도 셸 (가입 게이트웨이 강제 제거)
- **하단 탭**: 지도 / 보관함 / **내일자리** / 채팅 / 더보기 — 비로그인 시 지도 외 회색 비활성 + 로그인 시트
- **더보기**: `나의 보관함` 제거, **내 이력서** 추가 (`/seeker/my-resume`)
- **지원·보관함 저장**: 비로그인 시 `SeekerLoginPromptSheet` 유도
- **지도 검색 CTA 버그**: 하단 탭에 가려짐 → `MapFloatingInsets`로 버튼·현위치 올림; 이동 감지 과필터 제거
- **지도 검색 UI**: 넓은 `MapSearchBar` 제거 → 우측 돋보기 → 전체 검색 화면(엔터/돋보기 시 지도 복귀)
- **기업회원 게스트**: `CorporateHomeShellPage` 둘러보기 — 홈(채용 지도)·더보기 활성, `run_corporate_web.sh`/`CORPORATE_WEB_QC` 진입, 게이트웨이「둘러보기」버튼
- **비로그인 UX**: 지도 우선 유지 + **더보기 탭 활성** + 상단·웹 레일 하단 `로그인`/`가입` 버튼, 제목 `둘러보기`

## 2026-06-19 — 개인회원 인증 전체 (본인인증·가입·찾기·재설정)

### 서버
- password_service, signup/find-email/password/reset, phone_verified_token

### 클라이언트
- IndividualAuthRepository, find_account_page, reset_password_page, 가입·로그인 연동

## 2026-06-19 — 이력서 5항목 양식 + 공고 필수 확인 항목

### 개인회원 이력서
- `SeekerResumeContent` — 학력·경력·면허·자격증·자기소개
- `SeekerResumeEditHubPage` — 섹션 허브·항목 추가/수정 (`/seeker/resume/edit`)
- 그리드·상세에 항목별 건수·본문 표시

### 기업 공고
- `CorporateJobPost.requiredResumeItems` — 5항목 FilterChip 선택
- 공고 등록·수정 폼 `ResumeRequiredItemsField`

### 지원 시 공개 동의
- `showResumeDisclosureFlow` — 미작성 시 이력서 작성 유도, 동의 후 지원
- `HiringApplication.disclosedResumeItems` — 기업은 동의 항목만 열람

## 2026-06-19 — 표준 자격·면허 DB + 사진 등록 + 공고 필수 자격

### 자격 DB (`CredentialCatalog` 14종, 4카테고리)
- 건설·제조, 물류·운전, 시설·경비, 미화·돌봄
- `CredentialSearchService` — 별칭 연관검색 (예: 지게차 → 조종사 면허 + 운전기능사)

### 개인회원
- `SeekerMyCredentialsPage` — 카테고리별 보유 체크 + 사진 업로드 필수
- 더보기 / 신분증·통장 페이지 / 이력서 면허·자격증 섹션 연동
- `SeekerMemberProfile.credentialHoldings` 저장

### 기업 공고
- `CorporateJobPost.requiredCredentialIds` — 검색·체크 선택
- `RequiredCredentialsField` — 공고 등록·수정 폼

### 지원
- `showRequiredCredentialsApplyDialog` — 필수 자격 목록 + 예/아니오(지원취소)

## 2026-06-19 — 길찾기(네이버 경로) + 지원 취소

### 길찾기
- `openNaverDirections()` — 네이버 지도 v5 **경로찾기** (`현위치 → 근무지`, 기본 `car`)
- 공고 상세 「길찾기」: 근무지 좌표·주소 + `DeviceLocationService` 출발지, `LocationConsentService.mapBrowse` 동의 후 실행
- 웹: `https://map.naver.com/v5/directions/-/{dest}/-/car` (출발 `-` = 현위치)

### 지원 취소
- `LocalHiringRepository.withdrawBySeeker` — applied/chatting/scheduled(출근 전) 취소
- `SeekerApplicationWithdrawService.confirmAndWithdraw` — 확인 다이얼로그 + JobApplication·셔틀 예약 정리
- UI: 공고 상세(닫기·**지원취소**·지원하기), 액션 그리드, 보관함(상세·메모 옆), 내 지원 탭

## 2026-06-19 — 문서·약관: 채용 성공 수수료 메인 앱 없음 정렬

- **사실**: `ENABLE_HIRING_COMMISSION` 기본 `false` — 출근 확인 후 수수료 결제·에스컬레이션 비활성
- **갱신**: `PUSH_PACKAGE_PRICING.md`, `PRODUCT_REQUIREMENTS.md`, `PRODUCTION.md`, `docs/disabled_features.md`, `.cursor/rules/*`, `dart-define.example`
- **약관 초안** `01_terms_of_service.md` 제9조 — 메인 서비스 채용 성공 수수료 미부과 명시
- **코드 주석**: `premium_partnership_tier`, `app_strings`, `roi_metrics_service` — 제휴 채널 전용 표기

## 2026-06-19 — Android APK 빌드 (1.0.0+2)

- `scripts/build_apk.sh` (mac/Linux) · `scripts/build_apk_release.bat` (Windows)
- 산출물: `releases/iljari-android-latest.apk`
- Gradle: compileSdk 36, Kotlin 2.0 플러그인 호환, `evaluationDependsOn` 제거
- 패키지 `kr.co.iljari.app` · 네이버 지도 키 포함 빌드

## 2026-06-26 — iljari.app 환경 일원화 (server / local)

- **server (기본)**: `api.iljari.app` · `app.iljari.app` — 포트·IP 제거
- **local (opt-in)**: `ILJARI_ENV=local` — 맥 hot reload만
- **nginx edge :80**: API 프록시 + Flutter web (`docker-compose` `edge` 서비스)
- **SSOT**: `scripts/environments.env` · `docs/ENVIRONMENTS.md`

- **원인**: `.command` / `run_*.sh`가 `flutter run` → `localhost:8082` 로컬 dev 서버 사용
- **해결**: `scripts/build_web_ncp.sh` + `deploy_web_ncp.sh` + `run_remote_web.sh`
- **nginx**: `server/docker-compose.yml` `web` 서비스 (:80), variant 경로 `/seeker/` `/corporate/` `/admin/` `/qc/` `/web/`
- **`.command` 전면**: NCP 배포 후 `http://app.iljari.app/<variant>/` 브라우저 오픈
- **DNS**: 가비아 `app` A → `211.188.56.77` · ACG TCP **80** 인바운드 필요

- **SSOT**: `scripts/remote_api.env` — `ILJARI_API_MODE=remote`, `http://api.iljari.app:8000`, Admin `iljari-admin-dev-key`
- **헬퍼**: `scripts/api_target.sh` — URL 해석, remote health check, local은 `ILJARI_API_MODE=local`일 때만 uvicorn
- **시드**: `scripts/seed_ncp_server.sh` — SSH → Docker `seed_qc.py` (로컬 DB 시드 제거)
- **run_*.sh** 전면: NCP health 대기, `COMPLIANCE_API_URL` remote 기본
- **build_apk.sh**: NCP API·Admin 키 기본 주입
- **문서**: `README.md`, `.cursor/rules/testing.mdc`, `SERVICE_READINESS.md`

## 2026-06-19 — 사이트 루트 배포 완료

- `finish_site_deploy.sh` + `도구_사이트완료.command` — 비밀번호 SSH로 site 빌드·업로드·nginx 루트 서빙
- 서버 `docker-compose.override.yml` 제거 (포트 충돌), API `8000:8000` compose에 반영
- 확인: `http://iljari.app/` HTTP 200, `base href="/"`, API health 200


- **질문**: 왜 URL 끝에 `/seeker`, `/health`가 붙는지 / 사용자도 `iljari.app/seeker`로 가는지
- **`/health`**: API 서버 살아있는지 확인용 (개발·모니터링). 사용자 URL 아님 → `api.iljari.app:8000/health`
- **`/seeker`**: 한 nginx에 여러 Flutter 웹 빌드(seeker/corporate/admin/qc) 나눠 둔 **내부 개발 경로**. 사용자에게 안내할 주소 아님
- **사용자 주소**: `http://iljari.app/` (루트). `site` variant + nginx `location /` 로 배포
- **실서비스 런처**: `실서비스_웹_개인회원.command` → `launch.sh web site server`
- **deploy_one_shot** 기본값 `site`로 변경, 루트 배포 경로 수정

## 2026-06-19 — 맵 우선 진입 + .command 정렬

- **진입 UX**: 비로그인 `iljari.app` → 구직 지도(`/home`) 먼저. 구석 로그인/가입 → `MemberLoginGatewayPage`(기업/개인 선택). `GuestAuthNavigation` 공통화.
- **`.command` 이름**: `실서비스|개발` → `앱|웹` → 회원분류 → (플랫폼). 예: `실서비스_앱_개인회원_안드로이드.command`
- **문서**: `docs/COMMAND_LAUNCHERS.md`, `README.md` 갱신

## 2026-06-27 — 어드민 API 오류 (PostgreSQL 스키마)

- **원인**: `ensure_qc_member_schema()` 가 SQLite만 처리 → NCP Postgres `qc_members`/`job_posts` 컬럼 누락 시 `/v1/admin/ops/stats` 등 500 → 어드민 빨간 `Failed to fetch`
- **수정**: `server/app/database.py` — Postgres `ADD COLUMN IF NOT EXISTS` 전체 컬럼 마이그레이션
- **어드민 UX**: `AdminApiErrors` 한국어 메시지, 공개 `/health`로 연결 판별 후 ops 오류 분리
- **배포 필요**: `./scripts/deploy_server_api.sh` + `도구_웹전체배포.command` (admin 재빌드)

## 2026-06-27 — 기업 담당자 코드 랜덤화

- **변경**: `1001` 순번 4자리 → **6자리 영숫자 랜덤** (`CorporateHandlerCodeGenerator`, 0/O/1/I/L 제외)
- **목적**: 가입 순서·「1001번째」 인상 제거 — 로그인용 아님, 사내 담당자 구분만

## 2026-06-27 — 기업 가입 OCR 대표자명 오류 수정

- **원인**: Mock/CLOVA OCR이 `대표자(OCR)` placeholder를 반환 → 실제 대표자명과 항상 불일치. 국세청 확인 통과 후에도 `validateStrict`가 가입을 차단.
- **수정**:
  - `ocr_business_cross_check` (Dart+Python): 한글 이름 정규화(공백·중점·괄호), 1~2자 fuzzy match, 대표자명만 불일치 시 관리자 검토로 완화
  - `business_verification_service`: NTS 통과 시 대표자명 OCR 불일치는 차단 대신 `adminReviewRequired`
  - `mock_business_certificate_ocr_service`: 대표자명 빈 문자열 (placeholder 제거)
  - `compliance.py`: NTS 확인 후 대표자명 OCR 교차검증 — 차단/검토 분리
- **테스트**: `ocr_business_cross_check_test`, `business_verification_service_test`, `test_ocr_cross_check.py` 통과
- **배포**: 앱 재빌드 필수. `COMPLIANCE_API_URL` 사용 시 `./scripts/deploy_server_api.sh` 로 API도 배포

## 2026-06-19 — 어드민 기업 등록증 승인 (서버 연동)

- **문제**: 친구가 본사 주소만 넣고 가입 → 어드민 **회원·이용권 → 기업회원**에 보이지만 **「등록증 승인」 버튼 없음**
- **원인**:
  - 본사 주소(`corporateProfile.businessHeadOfficeAddress`) ≠ 사업자등록증 제출·검증 큐
  - `AdminCompanyVerificationCard`가 **어드민 브라우저 SharedPreferences(로컬)** 만 조회 — 친구 기기 데이터 미반영
  - `POST /v1/auth/signup/corporate`는 `qc_members`만 생성, `companies` row 없음 → 서버 승인 API 404
- **수정**:
  - `GET/POST /v1/admin/ops/companies/{brn}/verification|approve-verification` — qc_member만 있어도 `needs_admin_approval: true`
  - `PATCH /v1/admin/companies/{key}/review` — Company 없으면 qc_member로 자동 생성 후 승인
  - `AdminCompanyVerificationCard` — `AdminOpsApiClient` 서버 상태 우선, 승인 버튼 표시
- **지금 당장 (배포 전)**: 같은 패널 **「이용권 부여」** 로 유료 크레딧은 줄 수 있음 (검증 승인과 별개)
- **배포**: `도구_실서비스한방배포.command` (API + admin 웹)

## 2026-06-19 — 공고 등록 «등록증·사업자 소재지 불러오기»

- **검토**: 국세청 odcloud API(홈택스 연동)는 **주소 필드를 반환하지 않음** — BRN·상태·업종만. 사업장 주소는 **등록증 OCR** 또는 **내정보 본사 주소**로 제공 가능.
- **추가** (기존 근무지 검색 유지):
  - OCR `businessAddress` · `VerifiedBusinessRecord.registeredBusinessAddress` 저장
  - `BusinessCertificateAddressExtractor` — 등록증 「사업장 소재지」 라인 파싱
  - 공고 등록/수정 폼 **「등록증·사업자 소재지 불러오기」** → Juso/지오코딩 → 근무지 채움
  - 본사 주소 미등록 시 불러온 주소를 **내정보 사업자 소재지**에도 자동 저장 (공고 검증 통과용)
- **테스트**: `business_certificate_address_extractor_test`

## 2026-06-19 — 개인회원 가입 2단계 분리

- **1단계 가입** (`IndividualSignUpFlow`): 휴대폰 본인인증(SMS, 추후 다날) + 이메일(아이디)·비밀번호·약관 → 지도 열람
- **2단계 프로필** (`SeekerProfileOnboardingFlow`): 이름·주민번호·실주소·근무지역·스케줄·사진 → `onboardingCompletedAt` 설정 후 지원 가능
- **지원 게이트**: `SeekerProfileReadiness` — 미완성 시 SnackBar + 더보기 「2단계 프로필 입력」
- **유지**: 비로그인 지도 우선 · 로그인/회원가입 선택 UX

