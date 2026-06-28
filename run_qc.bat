@echo off

setlocal EnableExtensions

title iljari QC Launcher

cd /d "%~dp0"



set "WEB_PORT=8080"

set "API_URL=http://api.iljari.app:8000"

set "ADMIN_KEY=iljari-admin-dev-key"



echo.

echo ========================================

echo   iljari QC (NCP API + Chrome, PG mock)

echo   API : %API_URL%

echo   App : http://localhost:%WEB_PORT%

echo   Local API: set ILJARI_API_MODE=local

echo ========================================

echo.



call :free_port %WEB_PORT%



echo [1/3] API health check...

curl -sf "%API_URL%/health" >nul 2>&1

if errorlevel 1 (

  echo ERROR: NCP API unreachable — %API_URL%/health

  echo   Seed data: scripts\seed_ncp_server.sh ^(Mac^)

  pause

  exit /b 1

)



echo.

echo [2/3] flutter pub get ...

call flutter pub get

if errorlevel 1 (

  pause

  exit /b 1

)



echo.

echo [3/3] Chrome QC 실행...

call flutter run -d chrome --web-hostname=localhost --web-port=%WEB_PORT% ^

  --dart-define=COMPLIANCE_API_URL=%API_URL% ^

  --dart-define=QC_MODE=true ^

  --dart-define=ADMIN_API_KEY=%ADMIN_KEY%



echo.

pause

exit /b 0



:free_port

set "TARGET_PORT=%~1"

for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%TARGET_PORT% " ^| findstr LISTENING') do (

  taskkill /F /PID %%P >nul 2>&1

)

timeout /t 1 /nobreak >nul

exit /b 0

