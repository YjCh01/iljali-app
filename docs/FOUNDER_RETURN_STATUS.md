# Founder Return — 서비스 총괄 점검 (2026-07-11)

> 돌아오실 때 한눈에 보는 **정식 출시 로드맵 재정리** + **현재 상태** + **에이전트가 밀어둔 작업**

---

## 정식 출시까지 — 두 축 로드맵

### A. 기술·QC (`LAUNCH_ROADMAP.md` 6단계)

| 단계 | 내용 | 상태 |
|------|------|------|
| 0 | 환경·QC 스크립트 | ✅ 대부분 완료 |
| 1 | 구직자 탐색 QC | ✅ |
| 2 | 구직자 버그·sync | ✅ |
| 3 | Auth·SMS·Toss 코드·staging | ✅ 코드 완료 |
| 4 | 구인자/구직자 웹 QC·AdaptiveSheet | ✅ |
| 5 | 컴플라이언스·Admin 승인 | ✅ |
| 6 | 약관·Sentry·스토어 베타 | ✅ **TestFlight 1.0.0 (4) iPhone OK** |

### B. 비즈니스·외부 심사 (`docs/PRE_TOSS_LAUNCH_ROADMAP.md`)

| 단계 | 내용 | 상태 |
|------|------|------|
| 0 | 실서버 확인·재배포 | 🔄 **최근 맵/빌드 수정 반영 배포 권장** |
| 1 | 무료 노출 프로모션 | ✅ `free_exposure_promo: true` |
| 2 | 소셜·웹 UI | 🔄 네이버 심사·구글 프로덕션 전환 대기 |
| 3 | 외부 키 (Toss·FCM·Juso 운영 등) | 🔄 Toss 심사 1~2개월 |
| 4 | 코드 마무리 (결제콜백·renewal·SMTP 등) | 🔄 일부 백로그 |
| 5 | 앱스토어·법무 | 🔄 Apple Developer 승인·변호사 검토 |
| 6 | 토스 연동 후 유료 전환 | ⏳ 심사 후 |

---

## 실서비스 헬스 (방금 확인)

`GET https://api.iljari.app/health`

| 항목 | 값 |
|------|-----|
| status | ok |
| free_exposure_promo | **true** (무료 노출 모드) |
| toss_configured | false (프로모션 유지) |
| juso / kakao geocode | configured |
| sms_provider | aligo |
| social_auth_mock | false (실소셜) |

웹: `https://iljari.app` · Admin: `https://iljari.app/admin/` — HTTP 200

---

## 이번 YOLO 세션에서 수정·보완한 것

### 버그 수정
1. **지도 강남 기본값** — `MapInitialCenterPolicy`: 기업=사업소재지, 구직자=집주소, 강남은 최후 fallback. 세션 캐시·로그아웃 시 초기화.
2. **웹/Android 빌드 실패** — `push_ticket_use_page.dart` `CorporateJobPost` import 복구.
3. **`map_exposure_visual_policy.dart`** — 잘못된 import 경로 수정 (`commute/domain/utils/shuttle_route_visibility.dart`).
4. **서버 pytest 5건 → 71 pass**
   - `conftest.py` — `drop_all` 후 스키마 자동 복구
   - `test_admin_ops` — 기업 가입에 휴대폰 인증 토큰 추가
   - `test_pilot_program` — QC seeker display_name 충돌 수정

### 기능 보완
5. **어드민 셔틀 참여자 UI** — 파일럿 패널에 `AdminShuttleParticipantsCard` (`GET /v1/admin/ops/shuttle/participants`)
6. **TestFlight 인프라** — fastlane·스크립트·ExportOptions (Apple Team ID 승인 후 업로드)

---

## TestFlight (2026-07-11 저녁)

| 항목 | 상태 |
|------|------|
| App Store Connect 앱 | ✅ 일자리 · `kr.co.iljari.app` |
| IPA 업로드 | ✅ `map.ipa` 1.0.0 (2) · App ID 6789877583 |
| ASC 빌드 표시 | ⏳ 처리 5~15분 (새로고침) |
| 내부 테스터 | ⏳ 아래 절차 |

### TestFlight 빌드가 「빌드 없음」일 때

1. **5~15분** 후 App Store Connect **새로고침**
2. **TestFlight → iOS 빌드** 섹션 확인 (처리 중 → 테스팅 가능)
3. **수출 규정(암호화)** 질문 뜨면 → 표준 HTTPS만 → **아니오**
4. 그래도 없으면 `./scripts/upload_testflight.sh --upload-only` 재실행

### 내부 테스트 시작 (샤워 후 5분)

1. TestFlight → **내부 테스팅** → **＋** 그룹 생성 (예: `팀`)
2. 본인 Apple ID(`ashronze@gmail.com`) 테스터 추가
3. iPhone **TestFlight** 앱 → **일자리** 설치

### 다음 업로드

- IPA만: `도구_TestFlight업로드만.command` 또는 `./scripts/upload_testflight.sh --upload-only`
- 빌드 번호 올리기: `pubspec.yaml`의 `version: 1.0.0+3` 후 전체 업로드

---

## 당신이 돌아오면 우선 할 일 (5~15분)

1. **TestFlight** — 빌드 처리 완료 확인 → 내부 테스터 추가 → iPhone 설치
2. **실서비스 배포** — `도구_실서비스한방배포(app포함).command` (맵·어드민 UI 반영)
3. **Java** (선택) — `도구_Java설치.command` (로그인 java.com 메시지 제거 + Android 빌드)
4. **아라컴퍼니** 로그아웃→재로그인 — 지도 안성 중심 확인

---

## 외부 대기 (코드 없음)

| 항목 | 비고 |
|------|------|
| Apple Developer Program | ✅ TestFlight 업로드 완료 — 내부 테스터·실기기 설치만 남음 |
| Toss PG 가맹 심사 | 1~2개월, 승인 후 `FREE_EXPOSURE_PROMO=false` |
| Google OAuth 프로덕션 게시 | 테스트 100명 제한 해제 |
| 네이버 로그인 심사 | 검수용 ID만 가능할 수 있음 |
| FCM 서비스계정 JSON | 서버 env |
| 변호사 약관 검토 | `store/legal/` |

---

## 에이전트 백로그 (다음 순)

1. [x] 어드민 셔틀 참여자 UI
2. [ ] AdaptiveSheet 웹 우측 패널 — 결제·알림핀·정류장
3. [ ] QC DB 스냅샷 export/import
4. [ ] 공고 full JSON server sync
5. [ ] Toss PG E2E (키 수령 후)
6. [ ] 급여지급일 서버 영속화
7. [ ] 카카오 알림톡
8. [ ] 근태 달력 MVP

---

## 검증 명령

```bash
cd server && python3 -m pytest tests/ -q          # 71 passed
flutter test test/core/map/map_initial_center_policy_test.dart
flutter analyze lib/features/admin/presentation/widgets/admin_shuttle_participants_card.dart
```

---

*에이전트는 YOLO 모드로 백로그·버그 수정을 이어갑니다.*
