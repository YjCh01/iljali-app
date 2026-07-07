# 토스 PG 전 출시 로드맵

> **목표:** 토스 가맹 심사(1~2개월) 동안 **핀·정류장 노출을 무료**로 열어 초기 기업 유입을 확보하고,  
> 그 사이에 **법적·인프라·스토어** 마감을 쉬운 것부터 순서대로 끝낸다.  
> 마지막 업데이트: 2026-06-19

---

## 한눈에 보기

| 단계 | 내용 | 담당 | 예상 |
|------|------|------|------|
| **0** | 이미 된 것 확인 + 웹 재배포 | 당신 5분 | 오늘 |
| **1** | 무료 노출 프로모션 (코드) | **에이전트 ✅** | 완료 |
| **2** | 소셜·웹 UI 마무리 | 당신 + 에이전트 | 1~2일 |
| **3** | 외부 심사·키 발급 대기 | 당신 | 병행 |
| **4** | 주소 API·푸시·결제 콜백 | 에이전트 | 1주 |
| **5** | 앱 스토어·법무 | 당신 + 변호사 | 2~4주 |
| **6** | 토스 PG 연동 후 유료 전환 | 당신 키 + 에이전트 | 심사 후 |

**확인 명령 (당신):** 브라우저에서 `https://api.iljari.app/health`  
→ `free_exposure_promo: true`, `toss_configured: false` 이면 무료 노출 모드 정상.

**배포 (당신):** 프로젝트 폴더에서 `도구_웹만배포.command` 더블클릭  
(앱 AAB는 Java 없으면 스킵되는 `도구_실서비스한방배포(no app).command` 사용)

---

## [0] 오늘 5분 — 확인만

### 당신이 할 일
- [ ] `https://iljari.app` 로그인 화면 — 카카오·네이버·구글 3개만, 폭 420px 정도인지 확인
- [ ] `https://iljari.app/pricing` 요금 안내 페이지 열리는지
- [ ] `https://iljari.app/corporate/` 로그인 후 상단 **「출시 기념 무료 노출」** 배너 보이는지
- [ ] 공고에서 알림핀·정류장 **결제 없이** 노출 활성화 되는지 (테스트 기업 계정)
- [ ] 위 확인 후 `도구_웹만배포.command` 실행 (코드 반영 안 됐으면)

### 에이전트가 해둔 것
- 무료 노출 정책 (`free_exposure_promo` / `FreeExposureLaunchPolicy`)
- 핀·정류장·셔틀 오버레이 활성화 시 결제·이용권 스킵
- 구인자 화면 상단 안내 배너

---

## [1] 무료 노출 프로모션 ✅ (에이전트 완료)

### 동작
- 서버에 `TOSS_SECRET_KEY` 없으면 → `GET /health` → `free_exposure_promo: true`
- 강제 끄기: 서버 `.env`에 `FREE_EXPOSURE_PROMO=false`
- 강제 켜기: `FREE_EXPOSURE_PROMO=true` (토스 키 넣은 뒤에도 잠깐 유지 가능)
- 토스 키 등록 + `FREE_EXPOSURE_PROMO=false` → 기존 유료·이용권 로직으로 복귀

### 관련 파일
| 영역 | 파일 |
|------|------|
| 서버 플래그 | `server/app/config.py`, `server/app/main.py` |
| 클라 정책 | `lib/core/config/free_exposure_launch_policy.dart` |
| 배너 | `lib/core/legal/widgets/free_exposure_launch_banner.dart` |
| 핀 활성화 | `lib/features/corporate/domain/services/job_pin_activation_service.dart` |
| 정류장 | `lib/features/commute/domain/services/shuttle_stop_activation_service.dart` |
| 셔틀 오버레이 | `lib/features/commute/domain/services/shuttle_overlay_activation_service.dart` |

### 당신이 할 일 (배포 후)
- [ ] 실서버 배포 1회 (`도구_웹만배포.command`)
- [ ] 기업 계정으로 핀 2개 이상·정류장 여러 개 무료 노출 테스트
- [ ] 문제 없으면 지인 기업 2~3곳에 「지금은 무료」로 초대

### 에이전트 추가 가능 (요청 시)
- [ ] PUSH 알림권도 프로모션 기간 무료 1회 (현재는 핀·정류장만)
- [ ] Admin에서 프로모션 ON/OFF 토글
- [ ] 무료 기간 종료 예고 메일/푸시

---

## [2] 소셜 로그인·웹 UI 마무리 (쉬움)

### 당신이 할 일
| 항목 | 할 일 |
|------|--------|
| **네이버 로그인** | 개발자센터 심사 결과 대기. 승인 전까지 **검수용 아이디**만 로그인 가능 — 테스터 이메일 등록됐는지 확인 |
| **구글 로그인** | OAuth 동의 화면 **프로덕션** 전환 (테스트 사용자 100명 제한 해제) |
| **카카오** | 이미 동작 중 — Redirect URI `https://api.iljari.app/v1/auth/social/kakao/callback` 유지 |
| **사업자 푸터** | `iljari.app` 하단 사업자정보(아라컴퍼니·540-31-00894·1644-5701) 노출 확인 |

### 에이전트가 해둔 것 / 추가 가능
- [x] Apple 로그인 제거
- [x] 로그인 카드 420px
- [x] `/pricing` 공개 요금 페이지
- [ ] 네이버 심사용 스크린샷·설명 문구 초안 (요청 시)
- [ ] 온보딩 슬라이드에 「지금은 무료 노출」 문구 반영 (요청 시)

---

## [3] 외부 심사·키 — 당신이 신청·대기 (코드 거의 없음)

| 서비스 | 상태 | 당신이 할 일 |
|--------|------|----------------|
| **토스 PG** | 심사 대기 1~2개월 | 가맹 심사 서류·정산계좌·`iljari.app/pricing` URL 제출 완료 여부 확인. 승인 후 `TOSS_CLIENT_KEY`, `TOSS_SECRET_KEY`, 웹훅 시크릿 → `도구_토스키_서버등록.command` (있으면) |
| **네이버 로그인** | 심사 제출됨 | 결과 알림·반려 시 수정 재제출 |
| **구글 OAuth** | 키 등록됨 | 프로덕션 게시 |
| **Aligo SMS** | `sms_provider: aligo` | 실번호 인증 테스트. 발신번호 등록·잔액 |
| **행정안전부 Juso** | `juso_configured: false` | [도로명주소 API](https://www.juso.go.kr) 승인키 → 서버 `.env` `JUSO_CONFM_KEY` |
| **CLOVA OCR** | 운영 키 | 사업자등록증 OCR — `CLOVA_OCR_*` 서버 등록 |
| **FCM** | 코드만 | Firebase 프로젝트·서비스계정 JSON → 서버 `FCM_SERVICE_ACCOUNT_JSON` |

### 에이전트가 할 일 (키 받으면)
- [ ] Juso 키 등록 스크립트 + 배포
- [ ] FCM 서버 env 등록 + 실기기 푸시 1건 테스트
- [ ] 토스 키 등록 + `FREE_EXPOSURE_PROMO=false` 전환 + 결제 E2E

---

## [4] 코드로 마무리할 것 (에이전트 — 중간 난이도)

우선순위 위에서 아래로.

| # | 항목 | 설명 | 담당 |
|---|------|------|------|
| 4-1 | **웹 결제 → 지갑 충전** | 결제 성공 콜백 후 서버 wallet 반영 누락 구간 | 에이전트 |
| 4-2 | **노출 연장(renewal)** | 프로모션 중 연장도 무료인지 정책 확정 후 반영 | 에이전트 |
| 4-3 | **이메일 SMTP** | 비밀번호 찾기·결제 영수증 | 에이전트 + 당신(Gmail 앱비번) |
| 4-4 | **알바몬 URL → 유령노선** | Admin에 URL 붙여넣기 → 스크래핑·지오코딩·미리보기 (MVP) | 에이전트 |
| 4-5 | **법무 `[[REVIEW]]` 치환** | 변호사 검토 받은 문구로 교체 | 당신 검토 후 에이전트 반영 |

### 당신이 할 일
- [ ] 4-5: `store/legal/` PDF·약관 초안 변호사에게 전달
- [ ] 4-3: 발송용 이메일 주소·SMTP 비밀번호 결정

---

## [5] 앱 스토어·운영 (당신 비중 큼)

| 항목 | 당신 | 에이전트 |
|------|------|----------|
| **Android AAB** | Mac에 Java: `brew install openjdk@17` 또는 Android Studio | 빌드 스크립트·서명 설정 점검 |
| **iOS TestFlight** | Apple Developer·인증서 | fastlane·버전 bump |
| **스토어 스크린샷** | 실제 기기·웹 캡처 | `store/` 가이드 참고 |
| **개인정보처리방침 URL** | `iljari.app` 약관 링크 스토어에 입력 | 이미 웹에 있음 |
| **Sentry DSN** | 프로젝트 생성 | `SENTRY_DSN` dart-define |

---

## [6] 토스 PG 승인 후 (유료 전환)

### 당신이 할 일
1. 토스에서 `live_ck_` / `live_sk_` 수령
2. 서버·웹 빌드에 키 등록 후 배포
3. `FREE_EXPOSURE_PROMO=false` (또는 env 삭제 — 토스 키 있으면 자동 OFF)
4. `/pricing` 금액·실결제 1건 테스트 (카드·간편결제)
5. 기존 무료 노출 기업에 「유료 전환 안내」 공지 (이메일·공지)

### 에이전트가 할 일
- [ ] 프로모션 OFF 후 회귀 테스트 (핀·정류장·PUSH·위임결제)
- [ ] `scripts/staging/test_toss_e2e.sh` 실서버 스모크
- [ ] 요금 페이지에 「출시 프로모션 종료」 문구 업데이트

---

## 지금 당장 추천 순서 (2026-07-02 갱신)

### ✅ 완료
- 네이버 로그인 검수 승인
- Juso + Kakao 주소·좌표 (`juso_configured`, `kakao_geocode_configured`)
- Aligo SMS, 카카오 로그인, 국세청 NTS
- 무료 노출 프로모션 코드

### 📋 다음 순서

| # | 할 일 | 담당 | 도구 |
|---|--------|------|------|
| 1 | **웹 배포** (유령핀·최신 코드 반영) | 당신 | `도구_웹만배포.command` |
| 2 | **서비스 상태 점검** | 당신 | `도구_서비스상태확인.command` |
| 3 | **무료 노출 테스트** + 지인 기업 2~3곳 초대 | 당신 | — |
| 4 | **구글 OAuth 프로덕션** 전환 | 당신 | `도구_구글OAuth프로덕션안내.command` |
| 5 | **약관 변호사 검토** 의뢰 | 당신 | `도구_약관PDF생성.command` |
| 6 | **FCM** Firebase JSON → 서버 | 당신 키 → 에이전트 | `도구_FCM키_서버등록.command` |
| 7 | **Android AAB** 준비 (Java) | 당신 | `도구_Java설치.command` |
| 8 | **웹 결제→지갑 충전** 코드 | 에이전트 | (토스 전 선행 작업) |
| 9 | **토스 PG** 심사 대기 → 승인 후 키 등록 | 당신 | `도구_토스키_서버등록.command` |

### 키 등록 도구 모음
- `도구_Juso키_서버등록.command` ✅
- `도구_Kakao주소키_서버등록.command` ✅
- `도구_FCM키_서버등록.command`
- `도구_토스키_서버등록.command` (심사 후)

---

## 이전 체크리스트 (참고)

```
□ 1. 도구_웹만배포.command 실행
□ 2. api.iljari.app/health → free_exposure_promo: true 확인
□ 3. corporate에서 핀·정류장 무료 활성화 테스트
□ 4. 지인 기업 2~3곳 무료 체험 초대
□ 5. 네이버·구글 심사/프로덕션 상태 주 1회 확인  ← 네이버 ✅
□ 6. Juso API 키 신청  ← ✅
□ 7. Aligo 실번호 SMS 1건 테스트  ← ✅
□ 8. brew install openjdk@17  ← 도구_Java설치.command
□ 9. 약관 변호사 검토 의뢰
□ 10. 토스 심사 진행 상황만 기다리기
```

---

## 참고 문서

| 문서 | 용도 |
|------|------|
| `LAUNCH_ROADMAP.md` | QC·기능 완료도 (개발자용) |
| `SERVICE_READINESS.md` | MVP vs 실서비스 갭 |
| `해야할일.txt` | 홈택스·토스·PG 상세 |
| `docs/FOUNDER_RETURN_REPORT_2026-07-01.md` | 결제·푸시 갭 리포트 |
| `PRODUCTION.md` | 배포·dart-define |

---

## 질문이 생기면

- **무료가 안 된다** → health에 `free_exposure_promo` 확인 → false면 토스 키가 들어갔거나 `FREE_EXPOSURE_PROMO=false`
- **배너가 안 보인다** → 웹 배포 안 됐거나 게스트(비로그인) 화면
- **네이버만 안 된다** → 심사 전이면 검수 계정만 가능
