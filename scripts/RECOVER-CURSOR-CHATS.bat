@echo off
echo === iljali Cursor chat FULL RECOVERY ===
echo Cursor will be closed. Save work in other apps first.
timeout /t 3
cd /d "%~dp0chat-sync"
node recover-all.mjs --kill-cursor --apply
echo.
echo Done. Re-open Cursor and open D:\1jari
pause
