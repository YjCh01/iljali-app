# iljali-app Cursor 대화 목록을 D:\1jari (GitHub: iljali-app) 워크스페이스에 재연결
# Cursor를 완전히 종료한 뒤 실행하세요.

param(
    [switch]$Apply,
    [switch]$ExportOnly
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot\chat-sync

if (-not (Test-Path node_modules)) {
    npm install --no-fund --no-audit
}

$nodeArgs = @('reindex-iljali-chats.mjs')
if ($Apply) {
    node fix-glass-repo-agents.mjs --apply
    $nodeArgs += '--apply'
}
elseif ($ExportOnly) { $nodeArgs += '--export-archive' }
else {
    node fix-glass-repo-agents.mjs
    $nodeArgs += '--analyze'
}

node @nodeArgs
