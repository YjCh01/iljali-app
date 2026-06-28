import 'package:flutter/material.dart';
import 'package:map/core/auth/guest_auth_navigation.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';

/// 비로그인 구직자 — 로그인·가입 유도
abstract final class SeekerLoginPromptSheet {
  static Future<void> show(
    BuildContext context, {
    String? message,
  }) {
    return showAdaptiveSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '로그인이 필요합니다',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              Text(
                message ??
                    '보관함·내일자리·채팅·더보기는 개인회원 로그인 후 '
                    '이용할 수 있습니다. 지도에서 일자리는 먼저 둘러보실 수 있어요.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  GuestAuthNavigation.openLogin(context);
                },
                child: const Text('로그인'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  GuestAuthNavigation.openSignUp(context);
                },
                child: const Text('회원가입'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
