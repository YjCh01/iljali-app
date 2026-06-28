# 네이버 클라우드 — Maps (Dynamic Map) 인증 정보

콘솔: **Maps → Application `iljari` → 인증 정보 → 변경**

## Web 서비스 URL — NCP 규칙 (중요)

공식 규칙 ([Maps 문제 해결](https://guide.ncloud-docs.com/docs/maps-troubleshoot.md)):

1. **`www` 빼고** 입력 → `http://www.iljari.app` ❌ · `http://iljari.app` ✅
2. **포트 번호 빼기** → `http://localhost:8080` ❌ · `http://localhost` ✅
3. **경로 빼기** — 호스트만
4. 서브도메인 있어도 **대표 도메인만** 등록

### 등록할 URL (복사해서 + 추가)

```
http://iljari.app
http://localhost
http://127.0.0.1
```

`http://www.iljari.app` 은 **형식 오류**로 거절됩니다 (공백 문제 아님).

브라우저에서 `www` 로 들어와도 NCP는 `iljari.app` 등록으로 인증합니다.

### 잘못된 예 (스크린샷에 있던 것)

| 입력 | 문제 |
|------|------|
| `http://www.iljari.app` | **www 포함** |
| `http://localhost:8080` | **포트 포함** |
| `http://localhost:8081` | **포트 포함** |

## Android / iOS

| 필드 | 값 |
|------|-----|
| Android 패키지 | `kr.co.iljari.app` (`com.example.map` 아님) |
| iOS Bundle ID | `kr.co.iljari.app` |

## 저장 후

`http://www.iljari.app/seeker/` 또는 `http://iljari.app/seeker/` 새로고침 (재배포 불필요).

## Client Secret

채팅·캡처에 올리지 말 것. Web 지도는 Client ID만 사용.
