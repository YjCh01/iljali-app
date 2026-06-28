# Play Console — 스토어 등록 텍스트

`store/README.md`와 동일 내용을 콘솔 입력란에 복사합니다.

## 기본 정보

| 필드 | 값 |
|------|-----|
| 앱 이름 | 일자리 |
| 패키지 | `kr.co.iljari.app` |
| 카테고리 | 비즈니스 |
| 콘텐츠 등급 | 청소년 이용 불가 또는 17+ (채용·위치) |

## 짧은 설명 (80자)

```
일용직·현장 채용 — 지도에서 공고 찾고, 지원하고, 셔틀·근태까지.
```

## 전체 설명

```
일자리는 물류·현장 중심 일용직 채용 플랫폼입니다.

【구직자】
· 지도 기반 공고 탐색
· 2단계 지원 · 기업 채팅
· 셔틀 예약 · 근태 확인

【기업회원】
· 무료 공고 등록
· 알림핀·PUSH로 주변 구직자 알림
· 지원자 관리 · 유료 노출

문의: iljariapp@gmail.com
```

## 개인정보처리방침 URL

- 스토어 필드: 앱 내 「더보기 → 약관 및 정책」 또는 배포 웹 `https://[도메인]/support/legal`
- PDF: `store/legal/pdf/02_privacy_policy.pdf`

## 심사용 테스트 계정

| 유형 | ID | 비밀번호 |
|------|-----|----------|
| 구직자 | seeker-0001@qc.iljari.co.kr | QcTest1234! |

심사 메모: QC_MODE 빌드 또는 스테이징 서버 연결 시 위 계정 사용.

## 업로드

```bash
./scripts/build_release.sh
./scripts/store_preflight.sh
# fastlane android beta  # Play service account 설정 후
```

## 체크리스트 (콘솔에서 직접)

- [ ] 앱 서명 키 (Play App Signing)
- [ ] 스크린샷 2종 이상 (`store/screenshots/`)
- [ ] 데이터 안전성 설문 (위치·연락처·결제)
- [ ] 통신판매업 신고번호 (관할 구청 — 별도 신고)
