# 일자리(map) — 프로덕션 연동 가이드

## Flutter 실행 (API + PG + OCR)

```powershell
cd d:\1jari\map
flutter pub get
flutter run --dart-define=COMPLIANCE_API_URL=http://10.0.2.2:8000 `
  --dart-define=NAVER_MAP_CLIENT_ID=YOUR_NAVER_MAP_CLIENT_ID `
  --dart-define=TOSS_CLIENT_KEY=test_ck_YOUR_KEY `
  --dart-define=CLOVA_OCR_URL=https://YOUR_APIGW.apigw.ntruss.com/custom/v1/XXXX/general `
  --dart-define=CLOVA_OCR_SECRET=YOUR_OCR_SECRET
```

| dart-define | 설명 |
|-------------|------|
| `COMPLIANCE_API_URL` | FastAPI 백엔드 (에뮬레이터: `10.0.2.2:8000`) · 건강보험 인증·상시직 수수료 API |
| `NAVER_MAP_CLIENT_ID` | 네이버 클라우드 Maps Client ID (SDK 초기화) |
| `TOSS_CLIENT_KEY` | 토스페이먼츠 클라이언트 키 |
| `CLOVA_OCR_URL` | CLOVA OCR Invoke URL |
| `CLOVA_OCR_SECRET` | X-OCR-SECRET |

전체 키 목록: `map/dart-define.example` · `lib/core/config/env_config.dart`

키 없으면 **mock OCR·mock PG·mock 지도(Windows)** 로 동작합니다.

## 네이버 지도 (Android/iOS 이중 설정)

SDK는 **dart-define**과 **네이티브 manifest** 양쪽에 동일 Client ID가 필요합니다. Windows 개발은 `NaverMapPlatform` 미지원으로 mock 지도가 표시됩니다.

| 단계 | 파일 | 설정 |
|------|------|------|
| 1 | `flutter run` / 빌드 | `--dart-define=NAVER_MAP_CLIENT_ID=...` |
| 2 Android | `android/local.properties` | `naver.map.client.id=...` (`local.properties.example` 참고) |
| 3 iOS | `ios/Flutter/Secrets.xcconfig` | `NAVER_MAP_CLIENT_ID=...` (`Secrets.xcconfig.example` 복사) |

체크리스트:

- [ ] 네이버 클라우드 콘솔에서 Maps Client ID 발급
- [ ] Android·iOS 앱 패키지명/번들 ID 등록
- [ ] dart-define + Android `local.properties` + iOS `Secrets.xcconfig` **동일 ID**
- [ ] `EnvConfig.isNaverMapConfigured` true 확인 (실기기/에뮬레이터에서 지도 타일 로드)

## 백엔드

```powershell
cd d:\1jari\server
pip install -r requirements.txt
copy .env.example .env
uvicorn app.main:app --reload --port 8000
```

`.env`: `NTS_API_KEY`, `TOSS_SECRET_KEY`, `CLOVA_OCR_*`, `CODEF_*` / `HYPHEN_API_KEY`, `BAROCERT_*` / `PORTONE_API_SECRET`, `INSURANCE_CI_SECRET`

## 상시직 건강보험 인증

| 우선순위 | 제공자 | `.env` 키 |
|---------|--------|-----------|
| 1순위 자격득실 | CODEF | `CODEF_CLIENT_ID`, `CODEF_CLIENT_SECRET`, `CODEF_PUBLIC_KEY` |
| 1순위 대안 | Hyphen | `HYPHEN_API_KEY` |
| 2순위 간편인증 | Barocert | `BAROCERT_LINK_ID`, `BAROCERT_SECRET_KEY` |
| 2순위 대안 | PortOne | `PORTONE_API_SECRET`, `SIMPLE_AUTH_CALLBACK_URL` |

키 미설정 시 mock 간편인증 + mock 자격득실 조회. CI는 서버 AES-GCM 암호화 저장, 클라이언트에는 해시만 동기화.

API: `POST /v1/insurance-auth/sessions` → WebView 간편인증 → `GET /v1/insurance-auth/callback` → `POST /sessions/complete`

30일 배치: 서버 기동 시 6시간마다 자동 reverify (`REVERIFY_BATCH_*`), 수동 `POST /v1/insurance-auth/batch/reverify`

## 주요 플로우

1. **가입** — 갤러리/카메라 사업자등록증 → OCR → NTS 검증
2. **기본 플랜** — 공고 등록 무료 · 푸시 1km·일 1회 · 사업자번호당 보너스 5회 · 지원자 연락·채팅 포함
3. **푸시·거점 패키지** — 5,000원 = 거점 1 + 푸시 1 (1km) · 10/30/100회 번들 할인
4. **공고 등록** — 제휴사 여부 → 근로자 유형(일반/일용직/계약직) → 일자리 작성(근무일자 달력·급여 단위)
5. **푸시 소진** — 일 무료 → 보너스 → 패키지 크레딧 순 · 패키지 구매는 PaymentFlowHelper → WebView
6. **수수료** — 일용직 출근비 10,000원 · 상시직 5.5% (플랜 무관)
7. **관리자** — 더보기 → 컴플라이언스 대시보드 → 승인/정지

## 근무지 주소 검색 (Daum Postcode + Kakao 좌표)

**근무지 검색** 화면은 [Daum 우편번호 서비스](https://postcode.map.daum.net/) WebView(`daum_postcode_search` + `webview_flutter`)를 사용합니다. **Android/iOS에서만** WebView가 동작합니다.

**Windows·macOS·Linux** 등 데스크톱에서는 `webview_flutter` 플랫폼 구현이 없어 Daum 팝업을 띄울 수 없습니다 (네이버 지도와 동일). 이 경우 **QC용 직접 입력**으로 샘플 좌표(강남)와 함께 근무지를 저장해 공고 등록·이후 플로우 테스트를 이어갈 수 있습니다.

선택한 도로명 주소의 **위·경도**는 Kakao Local REST API로 보완합니다.

| dart-define / `.env` | 설명 |
|----------------------|------|
| `KAKAO_REST_API_KEY` (dart-define) | 좌표 보완 · [Kakao Developers](https://developers.kakao.com) REST API 키 |
| `KAKAO_REST_API_KEY` (server `.env`) | 아래 Juso 검색용 |

키 없으면 주소는 저장되지만 좌표는 비어 있을 수 있습니다 (출근 GPS·지도 거점 등에 영향).

### 지점·푸시 거점 검색 (Juso + Kakao)

지점 관리·푸시 거점 인라인 검색은 서버 `/v1/addresses/search` 를 통해 **행정안전부 도로명주소(Juso)** API를 사용합니다.

| `.env` 키 | 설명 |
|-----------|------|
| `JUSO_CONFM_KEY` | [business.juso.go.kr](https://business.juso.go.kr) 승인키 |
| `KAKAO_REST_API_KEY` | Kakao Developers REST API 키 |

Flutter는 `--dart-define=COMPLIANCE_API_URL=...` 만 설정하면 됩니다. **서버 배포 없이** `--dart-define=KAKAO_REST_API_KEY=...` 만으로도 전국 주소 검색이 가능합니다. 키 없으면 강남 일대 샘플 주소만 검색됩니다.
