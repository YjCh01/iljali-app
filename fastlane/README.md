# fastlane

스토어 업로드 자동화 스켈레톤. 실제 업로드 전 Apple/Google 계정·키 설정 필요.

## 사전 준비

| 플랫폼 | 필요 |
|--------|------|
| iOS | Apple Developer, App Store Connect API key 또는 Apple ID, Xcode 서명 |
| Android | Play Console, service account JSON (`fastlane/play-store-key.json` — gitignore) |

## 사용

```bash
./scripts/build_release.sh
./scripts/store_preflight.sh

# iOS TestFlight
bundle exec fastlane ios beta

# Play internal track
bundle exec fastlane android beta
```

## 환경 변수 (예시)

```bash
export FASTLANE_USER="your@apple.id"
export FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD="..."
export SUPPLY_JSON_KEY_PATH="fastlane/play-store-key.json"
```

`Appfile`의 `app_identifier` / `package_name`은 `kr.co.iljari.app`으로 맞춰 두었습니다.
