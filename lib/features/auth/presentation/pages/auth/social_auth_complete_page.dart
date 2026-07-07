import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/auth/data/repositories/individual_auth_repository.dart';
import 'package:map/features/auth/domain/utils/auth_error_message.dart';
import 'package:map/features/auth/presentation/pages/auth/individual_social_sign_up_page.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';

/// 소셜 OAuth 콜백 — iljari.app/auth/social-complete
class SocialAuthCompletePage extends StatefulWidget {
  const SocialAuthCompletePage({super.key});

  @override
  State<SocialAuthCompletePage> createState() => _SocialAuthCompletePageState();
}

class _SocialAuthCompletePageState extends State<SocialAuthCompletePage> {
  String _message = '소셜 로그인 결과를 확인하는 중입니다…';
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _handleCallback();
  }

  Future<void> _handleCallback() async {
    if (!kIsWeb) {
      setState(() {
        _message = '소셜 로그인 콜백은 웹에서 이용해 주세요.';
        _done = true;
      });
      return;
    }

    final params = Uri.base.queryParameters;
    final status = params['status'] ?? '';
    final error = params['error'] ?? '';

    if (status == 'error' || error.isNotEmpty) {
      setState(() {
        _message = _errorMessage(error, params['provider'] ?? '');
        _done = true;
      });
      return;
    }

    if (status == 'login') {
      final token = params['access_token'] ?? '';
      if (token.isEmpty) {
        setState(() {
          _message = '로그인 토큰이 없습니다. 다시 시도해 주세요.';
          _done = true;
        });
        return;
      }
      try {
        await AuthSession.instance.setAccessToken(token);
        final client = IljariApiClient()..accessToken = token;
        final me = await client.fetchCurrentMember();
        await IndividualAuthRepository.completeRemoteLogin({
          ...me,
          'access_token': token,
        });
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.home,
          (_) => false,
        );
        return;
      } on Object catch (error) {
        if (!mounted) return;
        setState(() {
          _message = AuthErrorMessage.fromObject(error);
          _done = true;
        });
        return;
      }
    }

    if (status == 'signup_needed') {
      final socialToken = params['social_token'] ?? '';
      if (socialToken.isEmpty) {
        setState(() {
          _message = '가입 정보가 없습니다. 다시 시도해 주세요.';
          _done = true;
        });
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => IndividualSocialSignUpPage(
            args: IndividualSocialSignUpArgs(
              socialToken: socialToken,
              email: params['email'] ?? '',
              displayName: params['name'] ?? '',
              provider: params['provider'] ?? '',
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _message = '알 수 없는 소셜 로그인 결과입니다.';
      _done = true;
    });
  }

  String _errorMessage(String code, String provider) {
    final label = switch (provider) {
      'naver' => '네이버',
      'google' => 'Google',
      _ => '카카오',
    };
    return switch (code) {
      'kakao_secret_missing' =>
        '서버에 카카오 Client Secret이 없습니다. 관리자에게 문의해 주세요.',
      'kakao_invalid_client' =>
        '카카오 REST API 키 또는 Client Secret이 잘못되었습니다.\n'
        '카카오 콘솔 값을 서버 .env에 다시 넣어 주세요.',
      'kakao_redirect_mismatch' =>
        '카카오 Redirect URI가 일치하지 않습니다.\n'
        'https://api.iljari.app/v1/auth/social/kakao/callback 등록을 확인해 주세요.',
      'kakao_code_expired' =>
        '카카오 인증이 만료되었습니다. 로그인 버튼을 다시 눌러 주세요.',
      'kakao_profile_failed' =>
        '카카오 프로필을 가져오지 못했습니다. 카카오 로그인 동의 항목(닉네임)을 확인해 주세요.',
      'naver_not_configured' =>
        '네이버 로그인이 아직 설정되지 않았습니다. 관리자에게 문의해 주세요.',
      'naver_state_missing' =>
        '로그인 요청이 만료되었습니다. 처음부터 다시 시도해 주세요.',
      'invalid_state' =>
        '로그인 요청이 만료되었습니다. 처음부터 다시 시도해 주세요.',
      'naver_token_failed' =>
        '네이버 인증에 실패했습니다.\n'
        '콘솔 Callback URL이 https://api.iljari.app/v1/auth/social/naver/callback 인지, '
        'Client ID·Secret이 서버 .env와 일치하는지 확인해 주세요.',
      'google_not_configured' =>
        'Google 로그인이 아직 설정되지 않았습니다. 관리자에게 문의해 주세요.',
      'google_token_failed' =>
        'Google 인증에 실패했습니다.\n'
        '승인된 리디렉션 URI가 https://api.iljari.app/v1/auth/social/google/callback 인지, '
        'Client ID·Secret이 서버와 일치하는지 확인해 주세요.',
      'oauth_failed' => '$label 로그인 연동에 실패했습니다. 잠시 후 다시 시도해 주세요.',
      'account_restricted' => '이용 제한된 계정입니다. 고객센터에 문의해 주세요.',
      'missing_code' => '$label 인증이 취소되었거나 중단되었습니다.',
      _ => '소셜 로그인에 실패했습니다. 다시 시도해 주세요.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      body: AuthFormCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '소셜 로그인',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _message,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            if (_done) ...[
              const SizedBox(height: 24),
              AuthPrimaryButton(
                label: '로그인 화면으로',
                onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
                  AppRoutes.individualLogin,
                  (_) => false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
