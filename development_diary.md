- **고객센터 이메일**: iljariapp@gmail.com (`BusinessDisclosure` · 약관 · 스토어 listing)

## 2026-07-07 — 정류장 표시핀 프로모션 노출 버그

- **원인**: 노선·정류장 「등록」≠ 지도 「노출」 — 프로모션 시 결제 버튼 비활성 + 「노출 중」 오표시
- **수정**: `무료 노출 적용` 버튼 활성화, 실제 활성화(`exposureActivated`) 후에만 노출 완료 문구, 지도 `JobBoardRefresh`

## 2026-07-07 — 공고 삭제 서버 동기화 (부활 버그)

- **원인**: 삭제가 in-memory만 제거 → 재시작·bootstrap 시 서버 스냅샷으로 `replaceFromServer` 부활
- **수정**: `JobPostSyncService.pushDelete` + `DeleteCorporateJobPostUseCase` — DELETE `/v1/job-board/posts/{id}`
- **bootstrap**: 서버 공고 0건이면 로컬 목록도 비우도록 `_hydratePosts` 보강

## 2026-07-07 — 셔틀 정류장 그리드 인라인 시간·사진

- **정류장 행**: 편집/수정 텍스트 제거 → 사진 아이콘 + 시계(00:00) 칩, 햄버거·삭제 유지
- **시간**: `showShuttleStopTimePickerDialog` — 시계 칩 탭 시 HH:MM 팝업 (첫 정류장 필수 강조)
- **사진**: `ShuttleStopPhotoActions.pickFromGallery` — 그리드에서 바로 갤러리 연동
- **위치 조정**: 정류장 행 탭 → 지도 위치 조정 모드

## 2026-07-07 — 지원자 채팅 검증 제한 제거

- **정책**: 인증은 백오프ис용 — 채팅·즉시 확정은 기본 플랜 포함, 검증·관리자 검토·티어로 차단하지 않음
- **서버**: `evaluate_contact` — `is_suspended`만 차단 (legacy BASIC/Starter 티어 게이트 삭제)
- **클라이언트**: `ContactEntitlementService` admin review 블록 제거, 지원자·채팅 탭 「이용 제한」 카드 삭제
- **테스트**: `outsourcing_policy_test`, `test_contact_entitlement.py` (pytest 2 pass)

## 2026-07-06 — 셔틀 노선·선택 서버 영속화

- **노선**: `commute_routes` 테이블 + `GET/PUT/DELETE /v1/shuttle/routes` — 기업 저장·구직자(합격/공유동의) 조회
- **구직자 선택**: `seeker_shuttle_preferences` + `/v1/shuttle/preferences` — 회사당 노선·정류장 1건
- **클라이언트**: `CommuteRouteRepository`·`SeekerShuttleCommutePreferenceRepository` 서버 우선, 로컬은 캐시·최초 1회 업로드 마이그레이션만

## 2026-07-06 — 통근버스 합격 연동·서버 동기화

- **채용 확정 훅**: `ShuttleRouteShareOnHireSideEffects` — 셔틀 노선 있는 회사면 채팅 자동 안내 + `offerPending` 로컬·서버 offer
- **동의 통합**: 노선 공유 수신 = 관제탑 프로세스 참여 동의 (첫정류장/운전자 구분 없음)
- **서버**: `shuttle_route_share_consents` 테이블, `/v1/shuttle/route-share/*`, 어드민 `/v1/admin/ops/shuttle/participants`

## 2026-07-06 — 통근버스 노선·공유·추적 PRD 구현

- **기업 노선**: 첫 정류장 `departureTime` + 근무지 `arrivalTime` 필수 저장 (`ShuttleRouteSchedule.validateRequiredTimes`); 근무지 도착 시각 편집 UI
- **알림 시간대**: 기업 ±15분 / 구직자 추적 ±30분 (`ShuttleRouteSchedule`)
- **구직자**: 합격 후 「노선 공유 받기」 동의 → 회사 등록 **전체 노선** 표시 → **회사당 노선 1·정류장 1** 선택
- **관제탑**: 첫 정류장 선택 시 「노선 관제탑 알리미」 동의; 첫 정류장 운행 시각에 위치 ON 확인; 선택 노선 버스만 지도 표시
- **저장소**: `SeekerShuttleRouteShareConsent`, `SeekerCommuteTowerConsent` (SharedPreferences)
- **테스트**: `shuttle_route_schedule_test.dart` 4 pass

## 2026-07-05 — 어드민 근무지·본사 주소 불일치 검토 (API 연동)

- **서버**: `abuse_flags` 확장 컬럼 + `POST /v1/compliance/workplace-mismatch` (기업 Bearer) · `GET/POST /v1/admin/ops/compliance/workplace-mismatch/*` (Admin API Key)
- **승인**: 서버 `JobPostRow.status → recruiting` + 클라이언트 로컬 공고 동기화
- **클라이언트**: `WorkplaceMismatchFlagRepository` — API 우선, 오프라인 시 SharedPreferences 폴백
- **등록**: 불일치 시 `closed` 공고도 `JobPostSyncService.pushPost`로 서버에 저장 후 플래그 신고

## 2026-07-05 — 어드민 근무지·본사 주소 불일치 검토

- **흐름**: 사업자 본사 주소와 공고 근무지가 다르면 공고는 `closed`로 저장되고 컴플라이언스 플래그(`reviewStatus: pending`) 생성
- **기업 UX**: 등록·수정 시 「관리자 검토 중」 스낵바 후 목록으로 복귀 (`CorporateJobPostResult.pendingReview`)
- **어드민**: `컴플라이언스` 탭 → `AdminWorkplaceMismatchPanel` 2열 그리드 — 본사/근무지/거리 표시
- **승인**: 「기재된 근무지 그대로 공고 진행」 → `WorkplaceMismatchAdminService.approveStatedWorkplacePost` — 공고 `recruiting` + `JobPostSyncService.pushPost` + 플래그 `approved`

## 2026-07-03 — 어드민 알바몬 링크 일괄 가져오기

- **API**: `POST /v1/admin/ops/jobs/bulk-import-urls` — URL 스크래핑 → `bulk_import_jobs` (아라컴퍼니 기본)
- **UI**: 어드민 `공고·핀` 탭 — 링크 붙여넣기, 확인 시 최대 30건 등록, 빈 필드는 placeholder
- **옵션**: 일자리핀 자동 ON, Kakao 지오코딩(설정 시)
- **이미지 공고**: 텍스트 본문 없을 때 HTML `<img>` 추출 → `description_body_json` (html+images)

## 2026-07-03 — 웹 중앙 고정 폭 (좌우 광고 여백)

- **배경**: 알바몬·에펨코리아 등은 본문 ~1200px 중앙 정렬, 좌우에 배너 여백. 일자리는 풀 너비였음.
- **구현**: `WebCenteredSiteFrame` — 1140px 고정 본문 폭, 좌·우 **흰색** 여백. `MaterialApp.builder`로 전 화면 적용.
- **버그 수정**: 초기 1280px는 `min(1280, 뷰포트)`라 노트북(~1200px)에서 거터 0 → 풀 너비와 동일해 보였음. 이후 항상 1140px 고정 + 최소 24px 거터.
- **후속**: `leftGutter` / `rightGutter` 슬롯에 광고 위젯 연결 가능.

## 2026-07-03 — 지도 현재 위치 버튼 전 화면 통일

- **원인**: 기업 홈 지도는 `bottom: 16` 고정이라 하단 드래그 시트(26%)에 버튼이 가려짐. 도보 길찾기 지도는 버튼 자체가 없었음.
- **수정**: `MapFloatingInsets.myLocationAboveDraggableSheet` — 시트 위 여백 공통화. `CorporateHomeNaverMap.myLocationButtonBottom` 추가 후 기업 홈에서 전달.
- **추가**: `JobPostWalkingDirectionsMap` — 웹·네이티브 Stack + `MapCurrentLocationButton` + `MapCameraHolder` 바인딩.

## 2026-07-02 — 프로모션 어뷰징 방지 (activationSource + 월 10회 캡)

- `ExposureActivationSource` — promo | credit | payment
- 핀·정류장·셔틀 오버레이 활성화 시 source 기록
- `PromoExposureQuotaRepository` — 회사당 월 10회 무료 활성화 상한
- `PromoExposureCleanupService` — 프로모션 종료 시 promo 활성화만 회수
- 배너: 유료 전환 시 프로모션 노출 종료·재결제 안내

## 2026-07-02 — 지도보기 근무지 포커스 + 버튼명

- **공고보기 → 지도보기** (`corporate_job_post_card`) — 그리드가 이미 공고 안내, 버튼은 홈 지도 이동
- **근무지 좌표**: `resolveMapWorkplaceCoordinate*`가 알림 설정 0번(근무지) 좌표 사용 (강남 fallback만 쓰던 버그)
- **지도 포커스**: map ready 대기 후 카메라 이동, 강남 fallback 시 DB 저장 안 함 + 스낵바

## 2026-06-19 — 토스 PG 전 무료 노출 프로모션 + 출시 로드맵

- **서버**: `GET /health` → `free_exposure_promo` (기본: `TOSS_SECRET_KEY` 없으면 true). `FREE_EXPOSURE_PROMO` env로 강제 ON/OFF
- **클라**: `FreeExposureLaunchPolicy` — health 캐시 5분. 핀·정류장·셔틀 오버레이 활성화 시 결제/이용권 스킵
- **UI**: `FreeExposureLaunchBanner` — 구인자 `CorporateWebScaffold` 상단. 공고 유료서비스 패널 결제 UI 숨김
- **문서**: `docs/PRE_TOSS_LAUNCH_ROADMAP.md` — 당신 할 일 vs 에이전트 할 일, 쉬운 순서

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

## 2026-06-19 — 기업회원 홈 지도: 마감 핀 + 현 지도에서 검색

- `CorporateHomeMapBackground`: `includeClosedGhosts: true`, 내 공고 ID에 마감 공고 포함
- 개인회원과 동일 `MapSearchAreaButton` — 지도 이동 후 뷰포트 기준 핀 필터
- `CorporateHomeNaverMap`: `onCameraIdle` / `onMapReady` 콜백
- `CorporateHomeTab`: 마감 ghost 핀 탭 시 `ClosedGhostPinCalloutCard`

## 2026-06-19 — 공고 상세 길찾기 (도보 · 내 주소지)

- **기업회원**: 길찾기 탭 → `다른 기업의 공고입니다.` (구직자 미리보기는 버튼 숨김)
- **개인회원**: 더보기 실주소 → 근무지 핀, 네이버 지도 **도보** 길찾기
- 전용 화면 `JobPostWalkingDirectionsPage` (WebView) — 팝업보다 지도 영역이 넓어 채택
- 미로그인 → 로그인 유도 / 주소 없음 → `seekerHomeAddress` 안내
- `naver_directions_url.dart` URL 빌더 + 테스트

## 2026-06-19 — 지원 취소: 지원만 취소

- 확인 다이얼로그에서 채팅·셔틀 예약 해제 문구 제거
- 취소 시 `withdrawBySeeker` + 로컬 지원 목록만 정리 (셔틀 예약 삭제 로직 제거)

## 2026-06-19 — 보관함 캘린더 제거

- `IndividualVaultTab`: 날짜만 스낵바로 표시하던 「캘린더」 버튼·`_showCalendarStub` 삭제
- 근무/출근 탭(`IndividualWorkTab`) 출근 확정 일정 캘린더는 유지

## 2026-06-19 — 구직자 채팅 탭 목록 누락 수정

- `IndividualChatTab`: 탭 활성 시 `_load()` (기업 채팅 탭과 동일) + `HiringRefresh` 반영
- `commissionPaid` 등 완료 건도 채팅 목록에 표시 (`SeekerChatRoomListPolicy`)
- 근무 이력에서 열리던 채팅이 채팅 탭에도 보이도록 정렬

## 2026-06-19 — 어드민 기업 이용권: 3종 핀 +/−

- 회원·이용권: 일자리 알림핀 / 정류장 표시핀 / PUSH 알림권 각 1개 기본, − + 스테퍼
- API `wallet/grant`: `shuttle_stop_credits`, `push_ticket_credits` 추가
- DB `push_ticket_credits` 컬럼 + sync bootstrap 반영

## 2026-06-19 — 맵 공고 핀 터치 시 축척 유지

- `MapCameraHolder.focusPin`: `zoom` 기본값 14 제거 → null이면 현재 줌 유지, 중심만 이동
- 웹: `moveCamera(zoom: null)` → `setCenter` / 네이티브: `getCameraPosition().zoom` 재사용

## 2026-06-28 — 근무일정 협의 (전 고용형태)

- `WorkScheduleNegotiable` + `workScheduleNegotiable` — 일용·단기·계약·정규 공통
- 근무 일정 선택 아래 체크박스 — 체크 시 달력 미선택으로 등록 가능
- 저장·검증·미리보기·표시 라벨 연동

## 2026-06-28 — 공고 가져오기 → 직접 작성 폼 인라인

- 미리보기 그리드·별도 등록 화면 제거 — 가져오기 후 바로 아래에 `CorporateJobPostWriteFormHost` 표시
- 제목·근무지·급여·일정·업무내용·고용형태 자동 매칭 (`inferWorkerCategory`, 일정 미파싱 시 `근무일정 협의` 기본 체크)
- 그리드 탭 TypeError(별도 화면 `pushNamed<bool>`) 회피

## 2026-06-28 — QC 데모 주소(동탄대로 123) 실서비스 차단

- `QcDemoAddresses` — 레거시 QC 주소 감지·무시
- Mock OCR·캡처 OCR은 `DevExperienceFlags`에서만 동작, 실서비스는 빈 OCR
- 사업자 소재지 불러오기·등록증 저장 시 QC 주소 스킵
- 가져오기 후 근무지 자동 지오코딩 (`WorkplaceAddressResolver`)

## 2026-06-28 — 일용직 안내 얼럿 제거

- `DailyWorkerPolicy.showAcknowledgmentDialog` 삭제
- 일용직 선택 시 확인 다이얼로그·입력 게이트 제거 — 바로 근무일정·급여 입력 가능

## 2026-06-28 — 보건증 자격 DB 추가

- `health_certificate` — 식품·외식·제조 카테고리
- 건설 안전교육에서 잘못 묶여 있던 `보건증` 별칭 제거

## 2026-06-28 — 공고 본문 이미지 썸네일

- `JobPostDescriptionImage` — data URL(base64)은 `Image.memory`, https는 `Image.network`
- 작성·상세 화면 모두 실제 썸네일 표시 (웹에서 data URL 아이콘 fallback 제거)

## 2026-06-28 — 본사 주소 인라인 등록

- `BusinessHeadOfficeRegistrationFlow` — 공고 작성 중 본사 주소 팝업·주소 검색·근무지 동일 등록
- 등록 버튼·사업자 소재지 불러오기 실패 시 내정보 이동 대신 즉시 처리
- 핀 선택·기업 홈 핀 센터링은 줌 미지정; 홈 초기 진입 등은 기존처럼 `zoom` 명시

## 2026-06-19 — 마감유령핀 탭 안내

- 웹 지도: 유령핀 마커 ID(`ghost_*`) 매칭 누락 수정 → 탭 시 콜아웃 표시
- 개인·기업 홈: `ClosedGhostPinCalloutCard`에 「마감된 공고입니다.」 (내부 용어 제거)
- `ClosedGhostPinFeedback` 공통 스낵바 — 미니 지도 등 보조 UI

## 2026-06-19 — 실서버 MVP·데모·QC UI 정리

- 공고 가져오기: 「MVP 데모 안내」·데모 버튼·샘플 URL 폴백 제거 (QC debug만 유지)
- `DevExperienceFlags` — `kDebugMode && QC_MODE` 일 때만 내부 도구 노출
- 근무지 검색·결제·카드등록·알림설정·소셜가입 mock 문구 정리

## 2026-06-19 — 공고 가져오기: 미리보기 탭 → 편집

- 불러온 정보 그리드 탭 시 등록 작성 화면으로 바로 이동 (하단 버튼과 동일)
- 「직접 입력으로 등록」 제거 — 뒤로가기로 취소
- 업무·일정 `(확인 필요)` 표시 + 탭 유도 문구

## 2026-06-28 — 배포 빌드 수정 · 미리보기 탭

- `hiring_application.dart` → `hiring_application_status` export (`status.label` web compile)
- `CorporateSurfaceCard` InkWell clip·mouseCursor — 웹 탭 반응 개선

## 2026-06-29 — 그 외 자격증 (직접 업로드)

- `custom_*` + `customLabel` — 표준 목록 외 자격증 이름·사진 등록
- 자격·면허 등록 화면 하단 「그 외 자격증 (항목에 없음)」 섹션

- **검색 `보건`**: 보건증(식품) + 건설 안전보건교육 둘 다, 식품 먼저
- **자격 등록 화면**: 상단 「보건 관련」 고정 섹션, 식품 카테고리 최상단
- **저장 버그**: 로그인·동기화 시 `credentialHoldings` 합치기 (서버 프로필에 덮어쓰여 사라지던 문제)
- **UI 갱신**: `seekerProfileRevision` — 사진 업로드 후 즉시 반영

- **사업자등록번호**: 540-31-00894
- **주소**: 서울 송파구 오금로11길 55, 현대빌딩 2층 비즈센터
- `BusinessDisclosure` · assets/store legal · 동의 버전 `2026-06-29`

- **보건증**: `보건증 (건강진단결과서)` · 식품·외식 카테고리 · `보건` 검색 시 건설 안전교육 제외
- **QC DB**: `purge_qc_data.py` + `scripts/purge_qc_server.sh` + Admin `POST /v1/admin/ops/purge/qc`

- **QC 차단**: `QcVisualScenarioSeeder` QC_MODE 전용, QC 로그인·결제 mock 폴백·서버 QC 비번·OCR mock fail-closed
- **약관**: 언리얼리 → 아라컴퍼니 (`business_disclosure`, assets/store legal), 동의 버전 `2026-06-28`
- **점검 문서**: `실서비스_QC점검.txt`

- `해야할일.txt` — 홈택스(NTS/CLOVA), 다날, 토스 PG·간편결제, P0/P1 작업 순서 (맥 메모 앱에도 등록)

## 2026-06-29 — 웹 어드민 빌드 실패 수정

- `corporate_edit_job_post_page.dart`, `corporate_job_post_write_form_host.dart`: `retry.workplace!` (nullable 필드 promotion 불가)
- admin `flutter build web` 컴파일 성공 확인

## 2026-06-29 — 근무지·소재지 불일치: 등록 차단 해제

- 공고 저장 시 소재지 불일치 → 등록 계속, `AbuseDetectionService`에만 기록 (어드민 대시보드)
- `requiresAdminReview` 프로필 잠금·유료 차단·스낵바 경고 제거
- 본사 주소 미등록 시에만 등록 불가 유지

## 2026-06-29 — 공고보기 지도 포커스 (근무지 좌표)

- `JobPostWorkplaceResolver`: 강남 기본 좌표 저장값 무시 → `warehouseName` 지오코딩
- 공고보기: 카탈로그 핀 대신 공고 소재지 좌표로 지도 이동
- 지도 핀 좌표도 동일 resolver 적용

## 2026-06-29 — 공고보기 지도 강남 고정 (재수정)

- 지도용 좌표: 알림 거점 제외, `warehouseName` 지오코딩만
- 괄호·건물명 제거 후 `경기 안성시 소동산길 3-29` 등 다단계 geocode
- 공고보기: 카메라 즉시 이동 + viewport 필터 해제 + 좌표 DB 저장

## 2026-06-29 — 공고 상세 하단 버튼 축소

- `JobPostActionGrid`: 정사각형(AspectRatio 1) → 높이 48px 가로 버튼
- 웹 max-width 520px, 지원하기만 flex 2

## 2026-06-29 — 지원·콜아웃·미리보기 UX

- **근무일정 협의** 공고: 일정 없어도 지원 가능 → 채팅 협의 안내
- **지도 콜아웃**: 핀 근처(38%) · max 380px · compact 카드
- **구직자 미리보기**: 문의/지원/북마크 바 숨김 (회색 버튼 제거)

## 2026-06-29 — 로그인 실패 한국어 팝업

- `AuthErrorMessage` + `showAuthErrorDialog` — 비밀번호 오류·네트워크 오류 한국어 변환
- 로그인 실패 시 스낵바 → 확인 팝업
- 기업/개인 API 401·영문 오류 메시지 정리

- **삭제**: 지도에서 근무지(종점) 점 클릭 → 확인 후 삭제 · 배치 중 「이전 정류장 삭제」로 마지막 정류장부터 되돌리기

## 2026-06-29 — 유령노선도 어드민 배치 (정류장 개수 → 순서 선택)

- **유령노선도 만들기** → 개수 다이얼로그(근무지 포함, −/+) → 출발지 → 중간 정류장 → 근무지(종점) 순 지도 탭

## 2026-06-29 — 도보 길찾기 웹 지도 미표시

- **원인** `JobPostWalkingDirectionsPage`가 네이버 v5 길찾기 URL을 WebView에 embed — 웹에서 X-Frame 차단으로 빈 화면
- **수정** 앱 네이버 지도(출발·도착·점선) + 「네이버 지도에서 상세 경로」 새 탭

## 2026-06-29 — 유령노선도 UX·표시 재설계

- **배치**: 시작점 → 정류장 순서대로 → 「근무지 찍기」→ 근무지 (역순·노선시작점 버튼 제거)
- **표시**: 회색 점선 + 작은 번호 원(정류장) + 작은 사각 점(근무지) — 대형 유령핀 제거
- **서버**: 노선 생성 시 별도 `closed_ghost_pins` 자동 생성 안 함
- **어드민 지도**: 노선에 묶인 유령핀은 일반 유령핀 레이어에서 숨김

## 2026-06-29 — 어드민 공고 지도 좌표 버그 (강남 데모 오프셋)

- **증상** 아라컴퍼니(안성)·라인헬스케어 핀이 선릉/강남구청 인근에 표시
- **원인** `admin_ops_service._job_map_item`이 DB `workplace_latitude/longitude` 무시 · `37.5128,127.0471` 데모 중심 + 인덱스 오프셋만 반환
- **실제 DB** 아라 안성 `37.05,127.23` · 라인 테헤란로311 `37.50,127.04` (sync bootstrap 정상)
- **회색 핀 265건** = 마감유령핀(어드민 6/27~28 대량 배치), 공고와 무관 (`source_post_id` 없음)
- **수정** workplace 좌표 있으면 그대로 사용

## 2026-06-29 — 전체 공지 발송 (어드민 → 채팅 탭)

- **어드민** `공지 발송` 패널: 제목·본문 작성 → 전체 이용자에게 발송
- 서버 `admin_announcements` + sync bootstrap `admin_announcements`
- **구직자·기업** 채팅 탭 상단에 「일자리 운영팀」 읽기 전용 공지 (답장 불가, 미읽음 배지)
- FCM 미연동 — `push_channel: in_app_chat_notice` (앱 내 노출만)

## 2026-06-29 — 공지 수신 대상 분리 + 채팅 동기화 수정

### 공지 audience
- `admin_announcements.audience`: `all` | `seeker` | `corporate`
- 어드민 패널 SegmentedButton으로 대상 선택
- sync bootstrap `member_type` 쿼리로 서버 필터 + 클라이언트 `AdminAnnouncementRoomService` 이중 필터

### 채팅이 안 맞던 원인 (난이도 문제 아님 — 설계 갭)
1. **지원 ID 불일치**: 구직자 로컬 `app_{timestamp}` vs 서버 `app_{uuid}` → 같은 방인데 서로 다른 chat-sync 키
2. **가짜 웰컴 메시지**: 서버가 비어 있으면 `ensureWelcomeMessages`가 더미 대화 생성
3. **실시간 없음**: REST pull-only, 상대방은 채팅 재진입·폴링 전까지 못 봄
4. **서버 push 실패 무시**: `_pushToServer` catch로 조용히 실패

### 수정
- 지원 생성·sync 시 서버 canonical ID로 `_adoptServerApplicationId` + 채팅 키 `migrateApplicationId`
- API 모드에서 `loadSynced`는 빈 서버 응답도 그대로 반영 (웰컴 시드 X)
- 채팅 화면 5초 폴링으로 상대 메시지 갱신

## 2026-06-29 — 채팅 WebSocket 실시간 수신

- 서버 `GET /v1/chat-sync/ws/{application_id}?role=seeker|employer` — 방 구독
- REST `POST .../messages` 저장 후 같은 방 WebSocket으로 즉시 push
- 클라 `ApplicationChatRealtimeClient` — 채팅 화면 열면 연결, 끊기면 2초 후 재연결
- WS 끊김 시에만 10초 REST 폴백 폴링
- 단일 API 프로세스 MVP (다중 워커 시 Redis pub/sub 확장 가능)
- **배포 시 nginx `Upgrade` 헤더** 필요 (WebSocket)

## 2026-06-29 — FCM 푸시 (채팅·공지·PUSH 알림권)

### 서버
- `device_push_tokens` — 회원별 FCM 토큰·알림 설정
- `POST /v1/notifications/devices/register` — 로그인 후 토큰 등록
- `PATCH /v1/notifications/devices/preferences` — 채팅/일자리/지원 알림 on·off
- `POST /v1/notifications/push/recruitment` — PUSH 알림권 반경 매칭 → 구직자 FCM
- 채팅 REST 저장 · 어드민 공지 생성 시 FCM 자동 발송
- `FCM_SERVICE_ACCOUNT_JSON` env (Firebase 서비스 계정 JSON 한 줄)

### 클라이언트
- `firebase_core` + `firebase_messaging` (Web)
- `PushNotificationBootstrap` — 로그인 시 토큰 등록
- PUSH 알림권 발송 → 서버 API + 로컬 받은함
- `--dart-define` `FIREBASE_*` + `web/firebase-messaging-sw.js`

**배포 체크**: Firebase Console Web 앱 + VAPID 키 + 서비스 계정 JSON

**배포**: 웹 + API (`./scripts/deploy_prod_all.sh --web-only --no-app` + API)


- **유령노선도 추가**: 근무지(유령핀) → 정류장 역순 배치 → 「노선 시작점」으로 완료
- 서버 `closed_ghost_routes` + sync `ghost_routes`
- 지도 표시: 회색 점선만 (정류장 핀 없음) + 근무지 유령핀

- **정류장** (`pin_ref_bus_stop.png`): 둥근 사각 + 삼각 꼬리 · 그라데이션 · 그림자
- **알림** (`pin_ref_notification.png`): 링 물방울 (구멍 큼)
- **근무지** (`pin_ref_workplace.png`): 링 물방울 (구멍 작음 · 두꺼운 링)
- 유령·마감 → 근무지 스타일 + 회색
- 활성 → 파랑 `#6BAED6` (색상 커스텀은 추후)

## 2026-06-29 — 웹 배포 빌드 오류 수정 (MapConstants)

- `naver_map_web_layer_web.dart` — `map_constants` import 누락 복구 (핀 작업 중 실수)
- `build_web_ncp.sh` / `deploy_prod_all.sh` — 빌드 실패 시 **예전 산출물 업로드 차단**

**요구사항**
- 기업회원: 내/타사 공고 **본문 열람** OK · 지원·문의·북마크·길찾기 **불가**
- 개인회원: 열람 + 지원·문의·북마크 OK

**중앙 정책** `SeekerJobActionsPolicy`
- `canPerformSeekerActions` / `showSeekerActionUi` / `ensureCanApply`

**수정**
- `showJobApplyDialog` — 기업회원 차단 (개인만 지원)
- `JobPostDetailSheet` — 구직자 액션 UI·푸터 버튼 정책 적용
- `JobPostDetailPage` — 액션 그리드 정책 연동
- `individual_vault_tab` · `application_chat_page` — 지원 **이중 호출** 제거 (시트 내부 `_apply`만 사용)
- `JobProposalAcceptService.accept` — 기업회원 차단

**테스트** `seeker_job_actions_policy_test.dart` (2 cases pass)

## 2026-06-19 — 인증·찾기·재설정 (SMS 6자리 · PASS/아이핀 제외)

- **아이디 찾기**: 개인/기업 탭 · 연락처(이름+휴대폰) · 이메일 · 기업 사업자번호+담당자명
- **비밀번호 재설정**: 개인/기업 · 연락처/이메일 6자리 인증 후 변경
- **서버**: `account_recovery_service`, `email_verify_service`, `/v1/auth/email/*`, corporate find/reset
- **기업 가입**: `phone_verified_token` 필수 (소셜 포함 SMS 단계)
- **문구**: 본인인증/PASS → 휴대폰 문자 인증(6자리)
- **다음**: 소셜 OAuth 4종 (카카오→네이버→구글→애플)

## 2026-06-19 — 공고핀·정류장핀·PUSH 재점검 + QC 스토리지·어드민 증정 회수

**1) 상호 작동 (코드·테스트)**
- `ExposureSlotPolicy`: 정류장 미활성 → PUSH 차단, 알림핀 미활성 → PUSH 차단, 활성+좌표 일치 → 허용 (7 tests pass)
- `PushWalletCreditPolicy` / `PushWalletService` — 31 tests pass
- 흐름: **일자리 알림핀·정류장 표시핀 노출 활성화** → **PUSH 알림권**으로 해당 위치 발송 (`pushTicketBlockReason`)

**2) QC 스토리지 분리·제거**
- `QcLocalStoragePurge` — 실서비스(`QC_MODE=false`) 앱 기동 시 QC BRN·@qc 이메일·qc_ 공고·ghost_qc_ 핀 로컬 정리
- `QcSyncBootstrap` — 동일 QC 데이터 서버 pull 시 필터 (재유입 방지)
- 서버: `purge_qc_data` (기존) + `scripts/purge_qc_server.sh`
- **프로덕션 API 502** — 원격 purge 미실행, 배포 후 `./scripts/prod_cleanup_pins.sh --yes` 필요

**3) 가입·인증 자동 부여 핀 (정책)**
| 시점 | 클라이언트 | 서버 API |
|------|-----------|----------|
| 가입 보너스 | 일자리 알림핀 **2회** (`signupBonusPushes`) | BRN당 **5회** `signup_bonus_remaining` (불일치) |
| 사업자 검증 보너스 | 일자리 알림핀 **5회** (클라만) | 없음 |
| 근무지 무료 | 700m 회색 핀 1곳 | `BASE_LOCATION_SLOTS=1` |
| 일일 무료 PUSH | 사용 안 함 (deprecated) | `DAILY_FREE_PUSH=1` (레거시 필드) |

**4) 어드민 증정 무료핀 회수**
- `admin_grant_revoke_service.py` — audit `wallet.grant`·`entitlement.*` 역산 후 지갑·공고 entitlement 제거
- `POST /v1/admin/ops/wallet/revoke-admin-grants?dry_run=`
- `scripts/revoke_admin_grants_server.sh` · `scripts/prod_cleanup_pins.sh`
- 테스트: `test_admin_grant_revoke.py` (2 pass)

## 2026-06-30 — data.go.kr 국세청 API 키 발급

- 공공데이터포털 **기업 프로젝트 서비스키** 발급 (2026-06-30)
- `server/.env` 로컬: `NTS_API_KEY` + `REQUIRE_NTS_API_KEY=true` 반영
- **운영(NCP)**: SSH 키 인증 실패 — `/opt/iljari/server/.env` 수동 반영 + `docker compose up -d --build api` 필요
- **보안**: 키가 채팅에 노출됨 → data.go.kr에서 재발급 권장
- 확인: `GET https://api.iljari.app/health` → `nts_configured: true` (현재 API 502)

## 2026-06-30 — 고객센터·SMS 발신번호 1644-5701

- `BusinessDisclosure.phone` + assets/store legal 전역 `1644-5701`
- 알리고 발신: `server/.env` `SMS_SENDER_ID=16445701` (알리고 콘솔 발신번호 등록·승인 선행)

## 2026-06-30 — prod API crash: requests 누락

- `server-api-1` Exited(1): `google.auth.transport.requests` → `requests` 미설치
- 수정: `server/requirements.txt`에 `requests==2.32.3` 추가
- 운영 서버: `/opt/iljari/server/requirements.txt` 동일 반영 후 `docker compose up -d --build api`
- `server-edge-1` Restarting — SSL/nginx 별도 확인 (`docker compose logs edge`)

## 2026-06-30 — 지원 취소 후 목록 재등장 버그

- **원인**: `withdrawBySeeker` 로컬만 삭제 → `QcSyncBootstrap._mergeApplications` 가 서버 DB 지원 건 재병합
- **수정**: `DELETE /v1/hiring/applications?post_id&seeker_email` + 클라 tombstone + `withdrawApplication` API 호출
- **테스트**: `hiring_application_dedupe_test` withdraw, `test_job_sync` withdraw bootstrap

## 2026-07-01 — 창시자 모드 자율 점검·보완

- **보고서**: `docs/FOUNDER_RETURN_REPORT_2026-07-01.md` (복귀 시 「뭐했는지」 브리핑용)
- **지원 목록 갱신**: `IndividualApplicationsTab` + `HiringRefresh` + shell `isActive` — 지원 취소 후 「내 일자리」 탭 즉시 반영
- **로그인 보안**: 실서버 API 사용 시 개인 로그인 로컬 폴백 제거 — API 오류 시 유령 로컬 계정 진입 방지
- **미배포 번들**: withdraw·QC가드·1644·서류문구·FCM 등 — API+웹 배포 필요
- **대기(P0)**: 알리고 SMS(내일) · 토스 PG · FCM · ADMIN 키 교체 · QC DB purge

## 2026-07-01 — 알리고 SMS 실패 원인 (IP 미등록)

- **증상**: `.env` aligo + 포인트 충전 후에도 인증번호 미수신
- **API**: `POST /v1/auth/phone/send` → `sms_failed:인증오류입니다.-IP`
- **원인**: 알리고 **발송 서버 IP** 화이트리스트에 NCP `211.188.56.77` 미등록
- **조치**: smartsms.aligo.in → 문자API → 신청/인증 → IP 추가 → 앱 재시도

## 2026-07-01 — 인증번호 60초 제한 UX 개선

- **문제**: 가입 직후 비밀번호 재설정 시 같은 번호 `rate_limited` → 전 화면 실패처럼 보임
- **오해**: 제한은 **번호별**이지 전체 유저 동시 접속 제한 아님
- **수정**: 유효 코드 있으면 **재발송 없이 성공**(가입↔재설정 코드 공유) · 인증 완료 후 **즉시 새 문자** · 연타만 15초 스로틀
- **UI**: 60초 안내 문구 제거, 실패 시 「잠시 후 다시 시도」

## 2026-07-01 — SSH 접속 런처

- `도구_SSH접속.command` — NCP `root@211.188.56.77` 대화형 SSH (키 → 비밀번호)
- `도구_SSH공개키출력.command` — PEM → authorized_keys 등록용

## 2026-07-01 — API 배포 SSH 비밀번호 수정

- **원인**: `iljari_ssh.sh` osascript + SSH_ASKPASS → 비밀번호 깨짐·Permission denied
- **수정**: SSH ControlMaster — 터미널 직접 입력 1회 (도구_SSH접속과 동일)

## 2026-07-01 — 소셜 로그인 4종 골격

- **서버**: `/v1/auth/social/{kakao|naver|google}/start|callback` + `POST /social/signup`
- **DB**: `member_social_links` — provider ↔ 회원 연결
- **클라**: `SocialLoginButtons` — 네이버·카카오·Google (Apple 제거)
- **mock**: OAuth 키 없으면 자동 mock (개발·데모 가능)
- **실연동**: 각 콘솔 Redirect URI `https://api.iljari.app/v1/auth/social/{provider}/callback`

## 2026-07-01 — 토스 PG 심사 대비 (웹)

- `/pricing` 공개 요금 페이지 — 알림핀·PUSH 등 가격 + 사업자 푸터
- `SiteLegalFooter` — 로그인·게이트웨이 하단 사업자정보 (상호·대표·BRN·주소·전화)
- `web/index.html` noscript — 크롤러/심사용 정적 요금·사업자 텍스트
- 결제창 코드는 완료 — `TOSS_*` 키 수령 후 서버 등록만 남음


- Apple 버튼: 코드에서 이미 제거 — **웹 재배포 필요** (프로덕션은 구 빌드)
- `AuthFormCard` max-width 420px 중앙 정렬 (너부대대 해소)
- `SocialLoginButtons` Google·Naver·Kakao 3열 컴팩트 + 구분선


- 서버·클라 코드 이미 구현됨 (`/v1/auth/social/google/start|callback`)
- `도구_구글로그인키_서버등록.command` — Client ID/Secret 서버 등록
- Google Cloud: OAuth 클라이언트 **웹 애플리케이션**, 리디렉션 URI `https://api.iljari.app/v1/auth/social/google/callback`
- 테스트 단계: OAuth 동의 화면 **테스트 사용자**에 Gmail 추가 필요 (네이버 멤버 관리와 동일)


- **Apple**: UI·enum·서버 `SOCIAL_PROVIDERS`에서 완전 제거
- **네이버 버그 수정**: 토큰 교환 시 authorize와 동일한 `state` JWT 전달 (하드코드 `iljari` 제거)
- **UI**: `SocialLoginButtons` — Naver(초록) + Kakao(노랑) 한 줄, Google 전체 너비
- **오류 메시지**: `social_auth_complete_page` — provider별 네이버/카카오 안내
- **env.example**: 네이버 콘솔 Callback URL·제공 정보 주석 추가
- **운영 설정 필요**: `/opt/iljari/server/.env`에 `NAVER_OAUTH_CLIENT_ID`, `NAVER_OAUTH_CLIENT_SECRET`

## 2026-07-01 — 앱 아이콘 임시 디자인

- `assets/icon/app_icon_draft_1024.png` — 1024×1024 퍼플 그라데이션 + 지도핀·서류가방 심볼 (임시)
- `app_icon_1024.png` / `app_icon_foreground_1024.png` 교체 후 `dart run flutter_launcher_icons` 적용

## 2026-07-01 — 앱 아이콘 삼태극 문양

- `IljariIconPainter` — 삼태극(보라 `#7C5CFC` · 민트 `#5EEAD4` · 노랑 `#FFE566`) + 딥퍼플 그라데이션 배경
- `flutter test tool/export_app_icon_test.dart` → PNG + `flutter_launcher_icons` 재적용

## 2026-07-01 — 웹 배포 빌드 수정

- `main.dart` — `PushNotificationBootstrap` import 누락으로 `flutter build web` 실패 → import 추가
- `deploy_prod_all.sh` — macOS bash 빈 배열 `app_args[@]` unbound variable → 분기 처리

## 2026-07-03 — 실시간 버스 위치 관제 파일럿 (사전 준비)

- **목적**: 위치 동의한 개인회원 1명을 관제탑 역할로 사전 협의·파일럿 운영
- **어드민**: `파일럿` 탭 → 휴대폰 번호 검색 → 본인 확인 체크 → **셔틀위치담당자 승인**
- **구직자 앱**: 지정 회원만 더보기·채팅 상단에 「실시간 버스 위치 관제」카드 → 관제 허브 (`/seeker/bus-location-tower`)
- **허브 UI**: 위치 동의 · 운영팀 채팅 · 실시간 전송(준비 중) 3단계 + 지도 미리보기 플레이스홀더
- **서버**: `app_pilot_programs` 테이블, `GET /v1/pilot/bus-location-tower/me`
- **테스트**: `server/tests/test_pilot_program.py`

## 2026-07-04 — 셔틀위치담당자 기반 오늘 셔틀 추적

- **권한 규칙**: 어드민이 A를 셔틀위치담당자로 승인하면서 `company_key + route_id` 지정 → B/C/D/E는 오늘 같은 회사·같은 셔틀 예약이 서버 지원 row에 있을 때만 추적 가능
- **서버**: `bus_location_tower_sessions` 오늘 위치 세션, 담당자 위치 업데이트 API, 탑승자 권한 판정, 어드민 세션 중지 API
- **지원 동기화**: `JobApplicationRow`에 `commute_route_id/name`, `shuttle_stop`, `pickup_time`, `shift_date` 저장
- **구직자 앱**: 담당자는 현재 위치 공유/갱신 후 화면 열림 중 30초 자동 전송, 탑승자는 20초 자동 새로고침으로 최신 좌표·갱신시각 확인; 내 지원 > 셔틀 안내에 `오늘 셔틀 위치 확인`
- **어드민**: 휴대폰 검색 결과의 최근 셔틀 선택 chip 또는 수동 회사·노선 입력 → 본인 확인 후 승인; 오늘 위치 공유 중지/승인 해제
- **테스트**: `python3 -m pytest tests/test_pilot_program.py -q` 5 passed; 변경 Dart 파일 `dart analyze` no issues

## 2026-07-01 — 카카오 로그인 콜백 무시 버그

- **원인**: `/auth/social-complete` URL인데 `_resolveInitialRoute()`가 `home`만 반환 → 쿼리(`status=signup_needed` 등) 버려짐
- **증상**: 카카오 동의 후 아무 안내 없이 초기/로그인 화면 (휴대폰 중복 이전 단계)
- **수정**: `main.dart` social-complete 라우트 · 가입 시 기존 개인회원 번호면 카카오 계정 연결 · 오류 메시지 보강
- **추가 수정**: `app.dart` `onGenerateRoute` default가 게이트웨이로 떨어져 `/auth/social-complete` URL인데도 콜백 미처리 → `Uri.base.path` 우선 분기

## 2026-06-19 — 마감 공고 복사 후 지도에「마감된 공고」유령핀 겹침

- **증상**: 마감 공고 복사·재등록 후 같은 근무지 핀 탭 시「마감된 공고입니다」
- **원인**: 기존 마감 공고의 회색 유령핀(closed ghost)과 새 채용 공고 핀이 같은 좌표에 동시 표시
- **수정**: `ClosedGhostPinSuppressionPolicy` — 같은 회사·같은 근무지에 채용 중 공고가 있으면 유령핀 숨김
- **적용**: `job_map_pins_data_source._fetchClosedGhostPins`
- **테스트**: `closed_ghost_pin_test.dart` suppression 케이스 추가 (4 passed)

## 2026-07-02 — 네이버 로그인 검수용 PDF

- `tool/generate_naver_login_review_pdf.dart` — 서비스 소개·운영정책 소명서 생성
- 출력: `store/naver_login_review/일자리_서비스소개_네이버로그인검수.pdf`
- 한글 폰트: `store/naver_login_review/fonts/NotoSansKR-Regular.otf`

## 2026-07-02 — Juso·Kakao 주소 API 서버 등록 도구

- `도구_Juso키_서버등록.command` → `JUSO_CONFM_KEY`
- `도구_Kakao주소키_서버등록.command` → `KAKAO_REST_API_KEY` (지오코딩·지도 핀)
- `도구_서비스상태확인.command` / `도구_약관PDF생성.command` / `도구_Java설치.command`
- `도구_FCM키_서버등록.command` / `도구_토스키_서버등록.command` / `도구_구글OAuth프로덕션안내.command`
- `도구_어드민보안강화.command` — 어드민 키 교체 + /admin/ IP 제한 + 재배포
- `도구_어드민_IP추가.command` — IP만 추가/해제

## 2026-07-05 — 셔틀 근무 시작시간 · 내 버스 탭

- **근무 시작시간**: 어드민 파일럿 패널에서 `HH:MM` 지정 → 확인 다이얼로그(근무지 도착 간주·추적 중지 안내) → 저장. 해당 시각(KST) 이후 `arrived_at_workplace`, 위치 공유/추적 중지.
- **서버**: `app_pilot_programs.work_start_time`, `bus_location_tower_sessions.work_start_time` / `arrived_at_workplace`; status `phase=arrived_at_workplace`, `tracking_stopped_reason=work_start_arrived`.
- **내 버스**: 지원·근무 탭 3번째 세그먼트 + `/seeker/my-bus` — 네이버 지도에 노선·셔틀 핀·내 정류장, ETA 카운트다운(직선거리·평균 28km/h).
- **테스트**: `test_pilot_program.py` 6 passed.

## 2026-07-05 — 내 버스 · 채용 확정 + 셔틀 노선 회사

- **자격**: `fetchScheduledForSeeker`(출근 예정·상호 확인·채용 완료) + 회사 `CommuteRouteRepository` 활성 노선 1개 이상.
- **UI**: 회사별 → 노선별 정류장 **2열 그리드** 선택, 저장 시 `SeekerShuttleCommutePreference` + `ShuttleBooking` + 지원 건 서버 동기화.
- **추적**: 선택 정류장 기준 지도·탑승 시각; 파일럿 GPS 일치 시 ETA 실시간.
- **빈 화면**: 채용 확정 전 / 노선 미등록 / 비로그인 안내 분리.

## 2026-07-07 — 공고그리드 지도보기 → 근무지 중심 이동

- **원인**: 홈 지도가 `_ownPostIds`에 없으면 포커스 무시, 홈 탭 로딩 중 지도 미마운트, 지도 준비 전 카메라 이동 실패
- **수정**: `focusPost`/`findById`로 공고 조회, 로딩 중에도 지도 표시, 카메라 준비 폴링 강화, 상세주소 꼬리(예: `1234`) 지오코딩 후보 제거

## 2026-07-07 — 근무지·본사 불일치: 공고 즉시 게시 + 어드민만 알림

- **요청**: 본사(A)와 다른 근무지로 등록해도 얼럿·본사등록 팝업 없이 공고 바로 게시. 해당 기업 정보만 어드민 전송.
- **변경**: `WorkplaceAddressMismatchService` — `notifyAdmin`만, 등록 차단 제거. `Create/UpdateCorporateJobPostUseCase` — 항상 `recruiting`, 불일치 시 `_reportWorkplaceMismatchForAdmin`. 공고 작성 UI에서 `BusinessHeadOfficeRegistrationFlow` 가로채기 제거.


- **요청**: 공항버스 앱처럼 노선명·정류장 목록·버스 현재 위치를 세로 타임라인으로 표시.
- **구현**: `ShuttleRouteVerticalTracker` — 기업명·노선명 헤더, 정류장 세로 목록, GPS→구간 투영으로 버스 배지 위치, 내 정류장 하이라이트, 지도 토글.
- **연동**: `SeekerMyBusPage` 추적 패널 — 노선·정류장 선택 후 타임라인 기본 표시, 「지도」칩으로 지도 펼침.
- **테스트**: `shuttle_bus_timeline_position_test.dart` 4 pass.


- **원인**: `~/.iljari/ruby-3.3` 이 OpenSSL·psych(libyaml) 없이 빌드되어 `gem install cocoapods` 실패.
- **수정**: `scripts/install_openssl_mac.sh`, `scripts/install_libyaml_mac.sh` 추가; `install_ruby33_mac.sh`가 OpenSSL/psych 검증 후 자동 재빌드.
- **검증**: OpenSSL 3.3.2 + psych OK → CocoaPods 1.16.2 설치 완료 (`pod --version`).

## 2026-07-05 — CocoaPods pod install SSL 인증서 (한방배포 iOS)

- **원인**: 자체 빌드 OpenSSL에 CA 번들 없음 → `certificate verify failed (unable to get local issuer certificate)`.
- **수정**: `scripts/ensure_ssl_certs.sh` — `~/.iljari/ssl/cacert.pem` 다운로드 + `SSL_CERT_FILE` export; `ensure_cocoapods.sh`·`build_prod_app.sh`·`CocoaPods설치.sh` 연동.
- **검증**: `pod install` 성공 (Android AAB/APK·API·웹은 이미 배포 성공 상태).
