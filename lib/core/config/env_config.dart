/// Flutter `--dart-define` 빌드 설정.
///
/// 참고: `map/dart-define.example`, `PRODUCTION.md`
/// 건강보험 인증(CODEF/Hyphen/Barocert/PortOne) 키는 **서버** `server/.env` 전용.
/// 클라이언트는 [complianceApiBaseUrl]만 설정하면 `/v1/insurance-auth/*` API를 사용합니다.
abstract final class EnvConfig {
  /// 네이버 Maps Client ID — SDK 초기화(`main.dart`).
  /// Android `local.properties` · iOS `Secrets.xcconfig`에도 동일 값 필요.
  static const String naverMapClientId = String.fromEnvironment(
    'NAVER_MAP_CLIENT_ID',
    defaultValue: '',
  );

  /// FastAPI 백엔드 (건강보험 인증·상시직 수수료·OCR 프록시 등).
  static const String complianceApiBaseUrl = String.fromEnvironment(
    'COMPLIANCE_API_URL',
    defaultValue: '',
  );

  /// 사업자등록 검증 — 클라이언트 직접 호출 시 (권장: 서버 경유).
  static const String ntsApiKey = String.fromEnvironment(
    'NTS_API_KEY',
    defaultValue: '',
  );

  /// Kakao Local REST API — 서버 없이 전국 주소 검색
  static const String kakaoRestApiKey = String.fromEnvironment(
    'KAKAO_REST_API_KEY',
    defaultValue: '',
  );

  /// 토스페이먼츠 클라이언트 키 (test_ck_ / live_ck_)
  static const String tossPaymentsClientKey = String.fromEnvironment(
    'TOSS_CLIENT_KEY',
    defaultValue: '',
  );

  /// CLOVA OCR Invoke URL (서버 프록시 권장 — `server/.env`의 `CLOVA_OCR_*`)
  static const String clovaOcrInvokeUrl = String.fromEnvironment(
    'CLOVA_OCR_URL',
    defaultValue: '',
  );

  static const String clovaOcrSecret = String.fromEnvironment(
    'CLOVA_OCR_SECRET',
    defaultValue: '',
  );

  static bool get isNaverMapConfigured =>
      naverMapClientId.isNotEmpty &&
      naverMapClientId != 'YOUR_NAVER_MAP_CLIENT_ID';

  static bool get isComplianceApiEnabled => complianceApiBaseUrl.isNotEmpty;

  static bool get isTossPaymentsConfigured =>
      tossPaymentsClientKey.isNotEmpty &&
      !tossPaymentsClientKey.startsWith('YOUR_');

  static bool get isKakaoAddressConfigured =>
      kakaoRestApiKey.isNotEmpty && !kakaoRestApiKey.startsWith('YOUR_');

  static bool get isClovaOcrConfigured =>
      clovaOcrInvokeUrl.isNotEmpty && clovaOcrSecret.isNotEmpty;
}
