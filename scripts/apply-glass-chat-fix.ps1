# Cursor 종료 후 Glass iljali-app 대화 연결 패치 (125개)
# PowerShell: .\scripts\apply-glass-chat-fix.ps1

$ErrorActionPreference = 'Stop'

function Stop-Cursor {
    $names = @('Cursor', 'cursor')
    foreach ($n in $names) {
        Get-Process -Name $n -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
    Start-Sleep -Seconds 2
    $left = Get-Process -Name 'Cursor','cursor' -ErrorAction SilentlyContinue
    if ($left) {
        Write-Error 'Cursor가 아직 실행 중입니다. 작업 관리자에서 Cursor.exe를 모두 종료한 뒤 다시 실행하세요.'
    }
}

Write-Host 'Cursor 프로세스 종료 중...'
Stop-Cursor

Set-Location $PSScriptRoot\chat-sync
node fix-glass-repo-agents.mjs --apply
node reindex-iljali-chats.mjs --apply --export-archive
node verify-patch.mjs

Write-Host ''
Write-Host '완료. Cursor를 다시 실행하고 Agents > Repositories > iljali-app 을 확인하세요.'
