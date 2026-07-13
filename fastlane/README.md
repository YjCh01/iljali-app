fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios prepare_signing

```sh
[bundle exec] fastlane ios prepare_signing
```

Xcode 자동 서명 — 팀 ID 적용

### ios check_builds

```sh
[bundle exec] fastlane ios check_builds
```

App Store Connect 빌드 상태 (check_testflight.sh)

### ios register_app

```sh
[bundle exec] fastlane ios register_app
```

App Store Connect 앱 등록 (최초 1회 — kr.co.iljari.app)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

TestFlight 업로드 (build/ios/ipa/*.ipa)

### ios ship

```sh
[bundle exec] fastlane ios ship
```

서명 준비 + IPA 빌드 + TestFlight (upload_testflight.sh 에서 호출)

----


## Android

### android beta

```sh
[bundle exec] fastlane android beta
```

Play Console internal testing

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
