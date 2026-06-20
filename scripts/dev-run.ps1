# 일자리 Flutter Web — NAVER 실지도
Set-Location $PSScriptRoot\..

$naverId = $env:NAVER_MAP_CLIENT_ID
$defines = @('--web-hostname=localhost', '--web-port=8080')
$defines += '--web-define=NAVER_MAP_NCP_KEY=unset'

if ($naverId) {
  $defines += "--dart-define=NAVER_MAP_CLIENT_ID=$naverId"
  $defines += "--web-define=NAVER_MAP_NCP_KEY=$naverId"
  if (Test-Path 'naver_map_client_id.txt') {
    Copy-Item 'naver_map_client_id.txt' 'web\naver_map_client_id.txt' -Force
  }
}

flutter run -d chrome @defines @args
