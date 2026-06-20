@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title 네이버 지도 Client ID 설정

if not exist "naver_map_client_id.txt" (
  copy /Y "naver_map_client_id.txt.example" "naver_map_client_id.txt" >nul
)

echo.
echo ========================================
echo   네이버 지도 키 설정
echo ========================================
echo.
echo   NCP 콘솔 - Application - [인증정보] 탭
echo.
echo   [O] Client ID     ^(클라이언트 아이디^)  ^<-- 이것만 복사
echo   [X] Client Secret ^(클라이언트 시크릿^) ^<-- 절대 넣지 마세요
echo.
echo   메모장이 열립니다. 안내문을 지우고 Client ID 한 줄만 붙여넣고
echo   저장(Ctrl+S) 하세요.
echo.
start "" notepad "%~dp0naver_map_client_id.txt"
echo   저장 후 run_web.bat 을 다시 더블클릭하세요.
echo.
pause
endlocal
