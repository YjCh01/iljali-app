# 일자리(iljari.app) — 창시자 복귀 보고서
**작성**: 2026-07-01 (자율 점검·수정 세션)  
**대상**: 최영진 대표 복귀 시 「나 돌아왔다. 뭐했는지 보여줘」용

---

## 한 줄 요약

**실출시 기준으로 서비스는 “맵+지원+채팅+기업공고+결제골격”까지 갖췄지만, 서버 `.env` 미완(문자·토스·FCM)과 미배포 코드가 가장 큰 리스크다.**  
오늘 세션에서 **지원 취소 좀비 버그 수정**, **지원 목록 갱신**, **실서버 로그인 로컬 우회 차단**, **고객센터·서류 안내 문구** 등을 반영했다.

---

## 서비스 전체 플로우 (이해용)

### 구직자
1. **지도** — 공고 핀 탐색 (서버 sync로 공고 목록 수신)
2. **지원/문의** — 로컬 저장 → 서버 `POST /v1/hiring/applications`
3. **내 일자리** — 지원 현황·근무·출근
4. **채팅** — 지원 건별 채팅 (로컬 + 서버 WebSocket)
5. **서류** — 신분증·통장·자격증 등록 → 채팅 전송
6. **가입/로그인** — 서버 JWT + 휴대폰 OTP (현재 서버는 **문자 mock**)

### 기업
1. **공고 등록** — 로컬 + 서버 job-board 동기화
2. **지원자 관리** — 로컬 hiring + sync
3. **핀·푸시 패키지** — 토스 결제 → 지갑 크레딧 (클라이언트 충전; 웹 리다이렉트 시 끊김 위험)
4. **사업자 검증** — 국세청 NTS (**연동 완료**)

### 서버 (api.iljari.app)
- Auth, Sync bootstrap, Hiring, Payments, Admin ops, FCM(설정 시)
- PostgreSQL 운영

---

## 오늘(이 세션) 코드에서 한 일

| # | 영역 | 내용 | 상태 |
|---|------|------|------|
| 1 | **지원 취소** | 서버 `DELETE /v1/hiring/applications` + 클라 tombstone → sync 재등장 방지 | ✅ 코드·테스트 |
| 2 | **지원 목록 UI** | `HiringRefresh` 연동 — 취소 후 「내 일자리」 탭 갱신 | ✅ |
| 3 | **로그인 보안** | API 켜진 실서비스에서 개인 로그인 **로컬 폴백 제거** | ✅ |
| 4 | **고객센터** | 전화 **1644-5701** (앱·약관) | ✅ (배포 필요) |
| 5 | **서류 페이지** | 안내 문구 2줄 + 보라색 개인정보 문구 | ✅ (배포 필요) |
| 6 | **API 안정** | `requests` 패키지 누락 크래시 수정 | ✅ 서버 반영됨 |
| 7 | **국세청** | NTS 키 서버 `.env` | ✅ (대표님 작업) |

---

## 반드시 해야 할 일 (우선순위)

### 🔴 P0 — 유저가 바로 맞닥뜨리는 것

| 순서 | 할 일 | 담당 | 비고 |
|------|--------|------|------|
| 1 | **API + 웹 배포** | 맥 `도구_API배포` / `도구_웹전체배포` | 미배포 시 지원취소 버그·QC가드 그대로 |
| 2 | **알리고 SMS** | 대표님 (내일) | 발신번호 16445701 승인 + `.env` 4줄 |
| 3 | **라인헬스케어 등 찌꺼기 지원** | 배포 후 지원취소 1회 또는 서버 DELETE | tombstone으로 재발 방지 |

### 🟠 P1 — 수익·신뢰

| 순서 | 할 일 |
|------|--------|
| 4 | 토스 PG 키 + `PAYMENT_WEB_SUCCESS_URL` |
| 5 | 결제 후 **지갑 자동 충전** (웹 콜백·웹훅) — 아직 클라 의존 |
| 6 | FCM 서버 JSON + 앱 dart-define |
| 7 | `ADMIN_API_KEY` / `AUTH_TOKEN_SECRET` 운영값으로 교체 |

### 🟡 P2 — 품질

| 순서 | 할 일 |
|------|--------|
| 8 | QC 서버 DB purge (`scripts/purge_qc_server.sh`) |
| 9 | 공고 sync 필드 보강 (근무형태·셔틀 등) |
| 10 | 소셜 로그인 4종 (UI는 「준비 중」) |
| 11 | 이메일 SMTP (계정 찾기·비번 재설정) |

---

## 알려진 버그·한계 (솔직히)

1. **지원 취소** — 수정됐으나 **배포 전**에는 서버에 지원 건 남아 sync 시 재등장 가능 (최영진님 라인헬스케어 사례)
2. **문자 인증** — 서버 mock 시 코드 `123456` (알리고 전까지)
3. **결제** — 토스 키 없으면 mock; 웹 결제 성공 URL만 타면 **지갑 미충전** 가능
4. **푸시** — FCM 미설정 시 발송 무반응
5. **개인 로그인** — API 장애 시 이제 로컬 우회 없음 → **에러 표시** (의도적)

---

## 서버 `.env` 체크리스트 (실출시)

```env
# 완료 추정
NTS_API_KEY=...
REQUIRE_NTS_API_KEY=true

# 내일
SMS_PROVIDER=aligo
SMS_API_KEY=...
SMS_ALIGO_USER_ID=...
SMS_SENDER_ID=16445701

# 토스 승인 후
TOSS_SECRET_KEY=...
TOSS_CLIENT_KEY=...
TOSS_WEBHOOK_SECRET=...
PAYMENT_WEB_SUCCESS_URL=https://iljari.app/payment-success
PAYMENT_WEB_FAIL_URL=https://iljari.app/payment-fail

# 푸시
FCM_SERVICE_ACCOUNT_JSON=...

# 보안
ADMIN_API_KEY=<강한 랜덤>
AUTH_TOKEN_SECRET=<32자 이상>
```

---

## 배포 명령 (맥)

```bash
cd ~/Projects/iljari-app
./scripts/deploy_server_api.sh      # API (지원취소 DELETE 포함)
./scripts/deploy_prod_all.sh --web-only --no-app   # 웹
```

---

## 테스트 상태 (이 세션)

- `hiring_application_dedupe_test` — withdraw + merge 차단 ✅
- `test_job_sync::test_withdraw_application_removes_from_bootstrap` ✅
- `business_disclosure_test` — 1644-5701 ✅

---

## 대표님 돌아오시면 30초 브리핑

> 「국세청·API는 살아 있고, 지원 취소 버그 원인 찾아서 고쳤어. **배포만 하면** 라인헬스케어 같은 거 안 돌아와.  
> 내일 알리고만 넣으면 가입 문자 실서비스 전환.  
> 토스·FCM·어드민키는 아직 — 돈 받고 푸시 쏘려면 이어서 하면 돼.」

---

*상세 개발 로그: `development_diary.md`*
