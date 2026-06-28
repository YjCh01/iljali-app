# 일자리 — 스토어 베타 메타데이터 (Play Console / App Store Connect 입력용)

## 앱 정보

| 항목 | 값 |
|------|-----|
| 앱 이름 | 일자리 |
| Bundle ID / Package | `kr.co.iljari.app` |
| 카테고리 | 비즈니스 / 생산성 |
| 연령 | 17+ (채용·위치 정보) |

## 짧은 설명 (80자)

일용직·현장 채용 — 지도에서 공고 찾고, 지원하고, 셔틀·근태까지.

## 전체 설명 (요약)

일자리는 물류·현장 중심 일용직 채용 플랫폼입니다.

- **구직자**: 지도 기반 공고 탐색, 2단계 지원, 채팅, 셔틀 예약, 근태 확인
- **기업회원**: 무료 공고 등록, 알림핀·PUSH, 지원자 관리, 유료 노출·셔틀

## 테스트 계정 (심사용)

| 유형 | 계정 | 비밀번호 |
|------|------|----------|
| 구직자 QC | seeker-0001@qc.iljari.co.kr | QcTest1234! |
| 기업 QC | corp-alpha@iljari.test | (앱 내 가입 플로우) |

## 개인정보 처리방침 URL

- 앱 내: 더보기 → 약관 및 정책
- 웹 (staging): `https://app.staging.iljari.local/support/legal`
- PDF 초안 (법무 검토용): `store/legal/pdf/` — `dart run tool/generate_legal_pdfs.dart`로 재생성

## 빌드 업로드

```bash
# 실기기 sideload APK (mac/Linux)
./scripts/build_apk.sh

# Windows
scripts\build_apk_release.bat

# Play Console AAB
./scripts/build_release.sh
./scripts/store_preflight.sh
# Play: android/app/build/outputs/bundle/release/app-release.aab
# APK: releases/iljari-android-latest.apk
# iOS: Xcode → Product → Archive → TestFlight
```

## 스토어 등록 텍스트

- Play: `store/listing/play_store.md`
- App Store: `store/listing/app_store.md`
- 스크린샷: `store/screenshots/README.md`

## fastlane (선택)

`fastlane/` — TestFlight·Play internal track 자동화 스켈레톤
