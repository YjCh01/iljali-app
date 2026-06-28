# App Store Connect — 스토어 등록 텍스트

## 기본 정보

| 필드 | 값 |
|------|-----|
| 앱 이름 | 일자리 |
| Bundle ID | `kr.co.iljari.app` |
| 주 카테고리 | 비즈니스 |
| 부 카테고리 | 생산성 |

## 부제 / 프로모션 (선택)

```
지도에서 찾는 일용직·현장 채용
```

## 설명

```
일자리는 물류·현장 중심 일용직 채용 플랫폼입니다.

구직자: 지도 공고 탐색, 지원, 채팅, 셔틀·근태
기업: 무료 공고, 알림핀 PUSH, 지원자 관리

고객센터: iljariapp@gmail.com
```

## 키워드 (100자 이내)

```
일자리,일용직,알바,채용,물류,현장,지도,구인,구직
```

## 지원 URL / 개인정보 처리방침 URL

- 지원 URL: `mailto:iljariapp@gmail.com` 또는 웹 고객센터
- 개인정보: `https://[도메인]/support/legal`

## TestFlight 심사 정보

- 로그인: seeker-0001@qc.iljari.co.kr / QcTest1234!
- 위치 권한: 주변 공고·지도 표시용
- 카메라/앨범: 사업자등록증 업로드 (기업 가입)

## 업로드

```bash
./scripts/build_release.sh
cd ios && open Runner.xcworkspace
# Product → Archive → Distribute → TestFlight
# 또는: fastlane ios beta
```

## 체크리스트

- [ ] Apple Developer Program ($99/년)
- [ ] App Privacy (위치·연락처·사진)
- [ ] 스크린샷 6.7" / 5.5" (`store/screenshots/`)
- [ ] 수출 규정 · 암호화 (HTTPS만 사용 시 exempt 가능)
