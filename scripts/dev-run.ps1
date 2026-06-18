# 일자리 Flutter 개발 실행 (Chrome)
Set-Location $PSScriptRoot\..

flutter run -d chrome `
  --dart-define=FLUTTER_WEB_USE_SKIA=true `
  @args
