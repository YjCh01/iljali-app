import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/core/utils/oauth_redirect.dart' show oauthRedirectAssign;
import 'package:map/features/auth/domain/entities/social_provider.dart';

/// 소셜 로그인 — 서버 OAuth 리다이렉트
class SocialAuthService {
  SocialAuthService({IljariApiClient? client})
      : _client = client ?? IljariApiClient();

  final IljariApiClient _client;

  bool get isEnabled => EnvConfig.isComplianceApiEnabled;

  String startUrl({
    required SocialProvider provider,
    required MemberType memberType,
    String action = 'login',
  }) {
    final base = _client.baseUrlForSocial;
    final member = memberType == MemberType.corporate ? 'corporate' : 'seeker';
    final redirect = Uri.encodeComponent(socialAppRedirectUrl());
    return '$base/v1/auth/social/${provider.apiValue}/start'
        '?member_type=$member'
        '&action=$action'
        '&app_redirect=$redirect';
  }

  void startLogin({
    required SocialProvider provider,
    required MemberType memberType,
    String action = 'login',
  }) {
    if (!isEnabled) {
      throw StateError('서버 API가 연결되지 않았습니다.');
    }
    oauthRedirectAssign(startUrl(
      provider: provider,
      memberType: memberType,
      action: action,
    ));
  }

  Future<Map<String, dynamic>> completeSocialSignup({
    required String socialToken,
    required String phone,
    required String phoneVerifiedToken,
    String displayName = '',
    String password = '',
  }) {
    return _client.socialSignup(
      socialToken: socialToken,
      phone: phone,
      phoneVerifiedToken: phoneVerifiedToken,
      displayName: displayName,
      password: password,
    );
  }
}
