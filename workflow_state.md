# Workflow State

## Current Task

- **알바몬 본문 로고 오탐 수정** — BFF content scrape 완료 (배포·재등록 필요)

## Backlog (priority order)

1. [x] **이미지 공고 본문** — CDN 핫링크 → mirror+proxy
1. [x] **알바몬 로고 오탐** — 셸 C-Photo-View 대신 BFF `/v1/recruit/view/detail` content
2. [ ] **이벤트핑 지도 클릭 배치** — AdminMapPanel placement mode
3. [ ] **알바몬 JS/BFF 배포 후 기존 공고 재등록** — 로고 본문 clear 후 URL 재import
4. [ ] **핀 TEMP 정리**
5. [ ] **실서비스 배포** — API+웹
6. [ ] **네이버 Directions 교체**

## Definition of Done

- `flutter analyze` — **0 errors** (new files)
- `flutter test` / pytest targeted pass
- Pricing/copy matches final push policy
- `workflow_state.md` updated

## Progress

- [x] 프로덕션 media 이미지 육안 대조 → 전부 로고 확인
- [x] Albamon BFF detail content 경로 확인
- [x] bLogo/template/C-Photo-View 필터
- [x] remirror: placeholder 로고 import clear + source_url 시 rescrape
- [x] pytest albamon_bff + extractor

## Completed (recent)

- 2026-07-14 — 알바몬 본문 로고 오탐 → BFF content scrape
- 2026-07-14 — 이미지 공고 CDN 핫링크 수정
- 2026-07-14 — 알바몬 미리보기 후 선택 등록
- 2026-07-14 — 이벤트핑 + 알바몬 검색URL
- 2026-07-14 — 통근버스 메인급 IA + OSRM 도로 추종

## Blockers

- TestFlight Apple ID 비밀번호
- **실서비스 재배포** 후 「이미지 본문 재정비」+ 알바몬 URL 재등록 필요 (기존 공고에 source_url 없음)

## Verification

- Tests: `test_albamon_bff_scraper` + image extractor/mirror pass
- Live: `117737154` BFF → imgur 본문 이미지 1장 (로고 아님)
