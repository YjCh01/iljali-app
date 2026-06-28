# iljari.app — 들어가는 주소

## 사용자 / 테스트 / 실서비스 (앱 화면)

| 누가 | 주소 |
|------|------|
| **개인회원** | **https://iljari.app/** |
| **기업회원** | **https://iljari.app/corporate/** |
| **어드민** | **https://iljari.app/admin/** |

`도구_브라우저열기.command` = 개인회원 주소 열기

---

## api.iljari.app/health 는 앱이 아님

브라우저에 JSON만 보이는 페이지 = **서버 살아있는지 확인용**. 정상이면 `"status":"ok"`.

| JSON 필드 | 의미 |
|-----------|------|
| `status: ok` | API 정상 |
| `nts_configured: false` 등 | 아직 안 쓰는 연동 (토스·국세청 등) — **지금은 정상** |
| `mock` | SMS·인증 등 개발용 모드 — **지금은 정상** |

**사용자에게 줄 주소 아님.** 앱은 **https://iljari.app** 만.

---

## 실행 파일

| 용도 | 파일 |
|------|------|
| 웹 열기 | `도구_브라우저열기.command` |
| 웹 전체 배포 | `도구_웹전체배포.command` |
| 점검 | `도구_전체점검.command` |
