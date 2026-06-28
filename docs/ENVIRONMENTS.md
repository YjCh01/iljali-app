# 환경

## iljari.app (테스트 + 실서비스 공통)

| | URL |
|--|-----|
| 웹 | https://iljari.app/ |
| API | https://api.iljari.app |

SSOT: `scripts/environments.env`

## 로컬 개발 (맥만)

`ILJARI_ENV=local` — API `127.0.0.1:8000`, 웹 포트 `8082`

## DNS (가비아)

| 호스트 | A 레코드 |
|--------|----------|
| @ | NCP 서버 IP |
| www | NCP 서버 IP |
| api | NCP 서버 IP |

## NCP ACG 인바운드

TCP **80**, **443** (필수) · 8000은 외부 노출 불필요 (api.iljari.app 경유)
