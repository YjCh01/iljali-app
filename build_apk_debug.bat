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

echo Building debug APK...
flutter build apk --debug %NAVER_DEFINE%
set "EXIT_CODE=%ERRORLEVEL%"
if not "%EXIT_CODE%"=="0" exit /b %EXIT_CODE%

for /f "tokens=2 delims= " %%V in ('findstr /r "^version:" pubspec.yaml') do set "VERSION_LINE=%%V"
for /f "tokens=1 delims=+" %%A in ("%VERSION_LINE%") do set "VERSION_NAME=%%A"
if not exist "releases" mkdir releases
copy /Y "build\app\outputs\flutter-apk\app-debug.apk" "releases\iljari-%VERSION_NAME%-android-debug.apk" >nul
copy /Y "build\app\outputs\flutter-apk\app-debug.apk" "releases\iljari-android-latest-debug.apk" >nul

echo.
echo APK: %CD%\releases\iljari-android-latest-debug.apk
echo      %CD%\build\app\outputs\flutter-apk\app-debug.apk
if not defined NAVER_ID (
  echo Note: NAVER map key not set — Android shows mock map. Add naver.map.client.id to android\local.properties for real map tiles.
)
endlocal
