@echo off
setlocal EnableExtensions
title iljari QC Launcher
cd /d "%~dp0"

set "WEB_PORT=8080"
set "API_PORT=8000"
set "ADMIN_KEY=qc-admin-dev-key"

echo.
echo ========================================
echo   iljari QC (서버 + Chrome, PG mock)
echo   API : http://127.0.0.1:%API_PORT%
echo   App : http://localhost:%WEB_PORT%
echo ========================================
echo.

call :free_port %WEB_PORT%
call :free_port %API_PORT%

if not exist "server\.env" (
  copy /Y "server\.env.example" "server\.env" >nul 2>&1
)

echo [1/4] QC DB 시드...
cd /d "%~dp0server"
start "iljari-api" /MIN cmd /c "uvicorn app.main:app --host 127.0.0.1 --port %API_PORT%"
timeout /t 3 /nobreak >nul
python scripts/seed_qc.py --seekers 1000 --jobs fixtures/jobs.example.json --wallet-brn 1000000001 --wallet-credits 30
cd /d "%~dp0"

echo.
echo [2/4] flutter pub get ...
call flutter pub get
if errorlevel 1 (
  pause
  exit /b 1
)

echo.
echo [3/4] Chrome QC 실행...
call flutter run -d chrome --web-hostname=localhost --web-port=%WEB_PORT% ^
  --dart-define=COMPLIANCE_API_URL=http://127.0.0.1:%API_PORT% ^
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
