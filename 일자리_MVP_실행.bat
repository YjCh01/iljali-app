@echo off
chcp 65001 >nul
title 일자리 MVP 실행
echo.
echo  ========================================
echo    일자리 앱 MVP 실행 중...
echo    창이 뜨기까지 1~2분 걸릴 수 있습니다
echo  ========================================
echo.

cd /d "%~dp0"

where flutter >nul 2>&1
if errorlevel 1 (
  echo  flutter 명령을 찾을 수 없습니다.
  echo  Flutter SDK PATH 설정 후 다시 실행해 주세요.
  pause
  exit /b 1
)

REM geolocator_windows 빌드용 nuget.exe
set "NUGET_DIR=%~dp0tool\nuget"
if not exist "%NUGET_DIR%\nuget.exe" (
  echo  Windows 빌드 도구 nuget 준비 중 - 최초 1회
  if not exist "%NUGET_DIR%" mkdir "%NUGET_DIR%"
  if exist "%~dp0build\windows\x64\_deps\nuget-src\nuget.exe" (
    copy /Y "%~dp0build\windows\x64\_deps\nuget-src\nuget.exe" "%NUGET_DIR%\nuget.exe" >nul
  )
)
if not exist "%NUGET_DIR%\nuget.exe" (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe' -OutFile '%NUGET_DIR%\nuget.exe' -UseBasicParsing"
  if errorlevel 1 (
    echo  nuget 다운로드 실패 - 인터넷 확인 후 다시 실행해 주세요.
    pause
    exit /b 1
  )
)
set "PATH=%NUGET_DIR%;%PATH%"

REM Windows MVP: mock 지도. Android/iOS Naver Map은 local.properties + dart-define 필요.
flutter run -d windows

if errorlevel 1 (
  echo.
  echo  실행에 실패했습니다.
  echo  1. Windows 터미널 또는 PowerShell 열기
  echo  2. cd /d d:\1jari
  echo  3. flutter run -d windows
  echo.
  pause
  exit /b 1
)
