@echo off
setlocal EnableExtensions
title iljari Web Launcher
cd /d "%~dp0"

set "WEB_PORT=8080"

echo.
echo ========================================
echo   iljari 웹 실행 (Chrome)
echo   주소: http://localhost:%WEB_PORT%
echo ========================================
echo.

call :free_port %WEB_PORT%

set "NAVER_ID="
set "NAVER_DEFINE="
set "WEB_DEFINE=--web-define=NAVER_MAP_NCP_KEY=unset"

call :read_naver_id
call :validate_naver_id
if errorlevel 1 goto :setup_key
goto :sync_key

:setup_key
echo [안내] 네이버 Client ID 설정
echo   NCP - Dynamic Map + Web URL:
echo     http://localhost:8080
echo     http://localhost
echo.
if not exist "naver_map_client_id.txt" (
  copy /Y "naver_map_client_id.txt.example" "naver_map_client_id.txt" >nul
)
start "" notepad "%~dp0naver_map_client_id.txt"
echo   저장 후 아무 키...
pause >nul
call :read_naver_id
call :validate_naver_id
if errorlevel 1 (
  echo [경고] Client ID 없음 - mock 지도
  timeout /t 4 >nul
  goto :run_app
)

:sync_key
echo [OK] Client ID: %NAVER_ID:~0,4%****
if not exist "web" mkdir web
copy /Y "naver_map_client_id.txt" "web\naver_map_client_id.txt" >nul
set "NAVER_DEFINE=--dart-define=NAVER_MAP_CLIENT_ID=%NAVER_ID%"
set "WEB_DEFINE=--web-define=NAVER_MAP_NCP_KEY=%NAVER_ID%"
echo.

:run_app
echo 1. flutter pub get ...
call flutter pub get
if errorlevel 1 (
  pause
  exit /b 1
)
echo.

echo 2. Chrome 실행...
call flutter run -d chrome --web-hostname=localhost --web-port=%WEB_PORT% %WEB_DEFINE% %NAVER_DEFINE%
set "RUN_EXIT=%ERRORLEVEL%"

if not "%RUN_EXIT%"=="0" (
  echo.
  echo [실패] 실행이 끝났습니다 ^(코드 %RUN_EXIT%^).
  echo   Chrome 창을 모두 닫고 run_web.bat 을 다시 실행해 보세요.
  echo   그래도 안 되면 작업 관리자에서 dart.exe 를 종료하세요.
)

echo.
pause
exit /b %RUN_EXIT%

:free_port
set "TARGET_PORT=%~1"
echo [%TARGET_PORT% 포트] 이전 실행 정리 중...
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%TARGET_PORT% " ^| findstr LISTENING') do (
  echo   종료: PID %%P
  taskkill /F /PID %%P >nul 2>&1
)
timeout /t 2 /nobreak >nul
exit /b 0

:read_naver_id
set "NAVER_ID="
if exist "naver_map_client_id.txt" (
  for /f "usebackq delims=" %%L in ("naver_map_client_id.txt") do (
    set "NAVER_ID=%%L"
    goto :read_done
  )
)
:read_done
if defined NAVER_ID (
  for /f "tokens=* delims= " %%Z in ("%NAVER_ID%") do set "NAVER_ID=%%Z"
)
exit /b 0

:validate_naver_id
if not defined NAVER_ID exit /b 1
if "%NAVER_ID%"=="" exit /b 1
if /i "%NAVER_ID%"=="PASTE_CLIENT_ID_HERE" exit /b 1
if /i "%NAVER_ID%"=="YOUR_NAVER_MAP_CLIENT_ID" exit /b 1
exit /b 0
