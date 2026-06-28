@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "NAVER_DEFINE="
if exist "android\local.properties" (
  for /f "usebackq tokens=1,* delims==" %%A in (`findstr /i "^naver.map.client.id=" "android\local.properties"`) do (
    set "NAVER_ID=%%B"
  )
)
if defined NAVER_ID (
  if not "%NAVER_ID%"=="" (
    set "NAVER_DEFINE=--dart-define=NAVER_MAP_CLIENT_ID=%NAVER_ID%"
    echo Using NAVER_MAP_CLIENT_ID from android\local.properties
  )
)

for /f "tokens=2 delims= " %%V in ('findstr /r "^version:" pubspec.yaml') do set "VERSION_LINE=%%V"
for /f "tokens=1 delims=+" %%A in ("%VERSION_LINE%") do set "VERSION_NAME=%%A"

set "API_DEFINE="
if defined COMPLIANCE_API_URL (
  set "API_DEFINE=--dart-define=COMPLIANCE_API_URL=%COMPLIANCE_API_URL%"
)

echo Building release APK (kr.co.iljari.app %VERSION_NAME%)...
flutter build apk --release --dart-define=QC_MODE=false %API_DEFINE% %NAVER_DEFINE%
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" exit /b %EXIT_CODE%

if not exist "releases" mkdir releases
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\iljari-%VERSION_NAME%-android.apk" >nul
copy /Y "build\app\outputs\flutter-apk\app-release.apk" "releases\iljari-android-latest.apk" >nul

echo.
echo APK: %CD%\releases\iljari-android-latest.apk
echo      %CD%\releases\iljari-%VERSION_NAME%-android.apk
if not defined NAVER_ID (
  echo Note: NAVER map key not set — Android shows mock map. Add naver.map.client.id to android\local.properties
)
endlocal
