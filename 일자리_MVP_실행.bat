@echo off
chcp 65001 >nul
title 일자리 MVP 실행
echo.
echo  ========================================
echo    일자리 앱 MVP 실행 중...
echo    (창이 뜨기까지 1~2분 걸릴 수 있습니다)
echo  ========================================
echo.

cd /d "%~dp0"
REM Windows MVP: mock 지도 표시. Android/iOS Naver Map은 local.properties + --dart-define 필요.
flutter run -d windows

if errorlevel 1 (
  echo.
  echo  실행에 실패했습니다.
  echo  Cursor 없이도 아래 방법을 시도해 보세요:
  echo    1. Windows 터미널 또는 PowerShell 열기
  echo    2. cd d:\1jari\map
  echo    3. flutter run -d windows
  echo.
  pause
)
