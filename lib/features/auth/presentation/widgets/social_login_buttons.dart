import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/domain/entities/social_provider.dart';
import 'package:map/features/auth/domain/services/social_auth_service.dart';

/// 카카오 · 네이버 · Google 소셜 로그인 버튼
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({
    super.key,
    this.memberType = MemberType.individual,
    this.action = 'login',
  });

  final MemberType memberType;
  final String action;

  void _start(BuildContext context, SocialProvider provider) {
    final service = SocialAuthService();
    if (!service.isEnabled) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('서버 연결 후 소셜 로그인을 이용할 수 있습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }
    try {
      service.startLogin(
        provider: provider,
        memberType: memberType,
        action: action,
      );
    } on Object catch (error) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error.toString()),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.authBackground,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '소셜 계정으로 로그인',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary.withValues(alpha: 0.85),
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Google',
                background: Colors.white,
                foreground: AppColors.textPrimary,
                borderColor: AppColors.searchBarBorder,
                onTap: () => _start(context, SocialProvider.google),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Naver',
                background: const Color(0xFF03C75A),
                foreground: Colors.white,
                onTap: () => _start(context, SocialProvider.naver),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SocialButton(
                label: 'Kakao',
                background: const Color(0xFFFEE500),
                foreground: const Color(0xFF3C1E1E),
                onTap: () => _start(context, SocialProvider.kakao),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      elevation: borderColor != null ? 0 : 0,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: borderColor != null
                ? Border.all(color: borderColor!)
                : null,
            boxShadow: borderColor != null
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
