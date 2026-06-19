@echo off
title iljari Web Launcher
cd /d D:\1jari
echo ========================================
echo iljari 웹 실행 시작...
echo ========================================
echo.

echo 1. flutter pub get 실행 중...
call flutter pub get
echo pub get 완료
echo.

echo 2. Chrome으로 실행 중... (이 창은 그대로 두세요)
call flutter run -d chrome

echo.
echo 실행이 끝났습니다.
pause