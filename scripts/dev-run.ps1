# 일자리 Flutter Web — NAVER 실지도 (Web Dynamic Map Client ID 필요)
Set-Location $PSScriptRoot\..

$naverId = $env:NAVER_MAP_CLIENT_ID
$defines = @('--dart-define=FLUTTER_WEB_USE_SKIA=true')
if ($naverId) {
  $defines += "--dart-define=NAVER_MAP_CLIENT_ID=$naverId"
}

flutter run -d chrome @defines @args
