# Android APK 산출물

실기기 설치·QC용 APK는 빌드 후 이 폴더에 복사됩니다.

| 파일 | 설명 |
|------|------|
| `iljari-android-latest.apk` | 항상 최근 빌드 (덮어쓰기) |
| `iljari-{version}-android.apk` | 버전별 release APK |

## 빌드 (macOS / Linux)

```bash
./scripts/build_apk.sh
# 로컬 API 연동 실기기:
COMPLIANCE_API_URL=http://<맥_LAN_IP>:8000 ./scripts/build_apk.sh
```

**필수**: Android SDK + JDK 17 (`flutter doctor` 통과)

## 빌드 (Windows)

```bat
build_apk_debug.bat
scripts\build_apk_release.bat
```

## Play 스토어

```bash
./scripts/build_release.sh
# → android/app/build/outputs/bundle/release/app-release.aab
```

패키지: `kr.co.iljari.app` · 현재 버전: `pubspec.yaml`의 `version:`
