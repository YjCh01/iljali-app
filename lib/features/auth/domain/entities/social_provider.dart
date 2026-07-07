import 'package:map/core/config/env_config.dart';

/// 소셜 로그인 제공자
enum SocialProvider {
  kakao('kakao', '카카오'),
  naver('naver', '네이버'),
  google('google', 'Google');

  const SocialProvider(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

String socialAppRedirectUrl() {
  if (EnvConfig.complianceApiBaseUrl.contains('127.0.0.1') ||
      EnvConfig.complianceApiBaseUrl.contains('localhost')) {
    return 'http://127.0.0.1:8082/auth/social-complete';
  }
  return 'https://iljari.app/auth/social-complete';
}
