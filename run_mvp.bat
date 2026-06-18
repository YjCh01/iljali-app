@echo off
setlocal EnableExtensions
title Iljari MVP

cd /d "%~dp0"

if exist "C:\flutter\bin\flutter.bat" set "PATH=C:\flutter\bin;%PATH%"

set "FLUTTER_LOCAL=%LOCALAPPDATA%\flutter\bin"
if exist "%FLUTTER_LOCAL%\flutter.bat" set "PATH=%FLUTTER_LOCAL%;%PATH%"

where flutter >nul 2>&1
if errorlevel 1 (
  echo [ERROR] flutter not found.
  echo Install Flutter or add C:\flutter\bin to PATH.
  pause
  exit /b 1
)

set "NUGET_DIR=%~dp0tool\nuget"
if not exist "%NUGET_DIR%\nuget.exe" (
  echo Preparing nuget for Windows build...
  if not exist "%NUGET_DIR%" mkdir "%NUGET_DIR%"
  if exist "%~dp0build\windows\x64\_deps\nuget-src\nuget.exe" (
    copy /Y "%~dp0build\windows\x64\_deps\nuget-src\nuget.exe" "%NUGET_DIR%\nuget.exe" >nul
  )
)

if not exist "%NUGET_DIR%\nuget.exe" (
  where curl >nul 2>&1
  if not errorlevel 1 (
    curl -fsSL -o "%NUGET_DIR%\nuget.exe" https://dist.nuget.org/win-x86-commandline/v6.0.0/nuget.exe
  ) else (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\download_nuget.ps1" -OutDir "%NUGET_DIR%"
  )
  if not exist "%NUGET_DIR%\nuget.exe" (
    echo [ERROR] nuget download failed. Check internet connection.
    pause
    exit /b 1
  )
)

set "PATH=%NUGET_DIR%;%PATH%"

echo.
echo ========================================
echo   Iljari MVP - Windows
echo   First run may take 1-2 minutes
echo ========================================
echo.

flutter run -d windows
set "RUN_EXIT=%ERRORLEVEL%"

if not "%RUN_EXIT%"=="0" (
  echo.
  echo [FAILED] exit code %RUN_EXIT%
  echo Manual run:
  echo   cd /d %~dp0
  echo   flutter run -d windows
  pause
  exit /b %RUN_EXIT%
)

pause
endlocal
