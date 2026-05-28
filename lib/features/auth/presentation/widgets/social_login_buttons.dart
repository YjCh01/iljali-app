import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// Google · Apple · Naver · Kakao 소셜 로그인 버튼
class SocialLoginButtons extends StatelessWidget {
  const SocialLoginButtons({super.key});

  void _showComingSoon(BuildContext context, String provider) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$provider 로그인은 준비 중입니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.authBackground,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '또는 소셜 계정으로 로그인',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
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
                onTap: () => _showComingSoon(context, 'Google'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialButton(
                label: 'Apple',
                background: AppColors.authButtonDark,
                foreground: Colors.white,
                onTap: () => _showComingSoon(context, 'Apple'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _SocialButton(
                label: 'Naver',
                background: const Color(0xFF03C75A),
                foreground: Colors.white,
                onTap: () => _showComingSoon(context, 'Naver'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SocialButton(
                label: 'Kakao',
                background: const Color(0xFFFEE500),
                foreground: const Color(0xFF3C1E1E),
                onTap: () => _showComingSoon(context, 'Kakao'),
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
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: borderColor != null
                ? Border.all(color: borderColor!)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}
