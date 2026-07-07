# 네이버 로그인 검수 제출 자료

## PDF 생성

```bash
dart run tool/generate_naver_login_review_pdf.dart
```

→ `store/naver_login_review/일자리_서비스소개_네이버로그인검수.pdf`

폰트(`store/naver_login_review/fonts/NotoSansKR-Regular.otf`)가 없으면 스크립트가 안내합니다.
최초 1회: GitHub google/fonts에서 Noto Sans KR 다운로드 후 위 경로에 둡니다.

## 네이버 개발자센터 제출

1. [네이버 로그인 개발자센터](https://developers.naver.com/apps/) → 애플리케이션 **일자리**
2. 검수 신청 → **소명 내용 입력** (README 하단 초안 참고)
3. **파일 첨부**: 위 PDF + 서비스 화면 캡처 4~6장
4. 재검수 요청

## 권장 캡처

- `https://iljari.app` 로그인
- 구직자 지도·공고 상세
- 기업 공고 등록·사업자 검증
- Admin 제재/공고 관리 (있으면)
