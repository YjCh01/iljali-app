import 'package:flutter/material.dart';
import 'package:map/core/auth/guest_auth_navigation.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';

enum SeekerGuestAuthLayout { appBar, topBar, rail }

/// 비로그인 구직자 — 로그인·가입 진입 (셸 상단·레일)
class SeekerGuestAuthActions extends StatelessWidget {
  const SeekerGuestAuthActions({
    super.key,
    this.layout = SeekerGuestAuthLayout.appBar,
  });

  final SeekerGuestAuthLayout layout;

  void _openLogin(BuildContext context) => GuestAuthNavigation.openLogin(context);

  void _openSignUp(BuildContext context) => GuestAuthNavigation.openSignUp(context);

  @override
  Widget build(BuildContext context) {
    if (SeekerShellAccess.isSignedInSeeker) {
      return const SizedBox.shrink();
    }

    return switch (layout) {
      SeekerGuestAuthLayout.appBar => _AppBarActions(
          onLogin: () => _openLogin(context),
          onSignUp: () => _openSignUp(context),
        ),
      SeekerGuestAuthLayout.topBar => _TopBarActions(
          onLogin: () => _openLogin(context),
          onSignUp: () => _openSignUp(context),
        ),
      SeekerGuestAuthLayout.rail => _RailActions(
          onLogin: () => _openLogin(context),
          onSignUp: () => _openSignUp(context),
        ),
    };
  }
}

class _AppBarActions extends StatelessWidget {
  const _AppBarActions({
    required this.onLogin,
    required this.onSignUp,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onLogin,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 40),
          ),
          child: const Text('로그인'),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: onSignUp,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('가입'),
          ),
        ),
      ],
    );
  }
}

class _TopBarActions extends StatelessWidget {
  const _TopBarActions({
    required this.onLogin,
    required this.onSignUp,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: onLogin,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: const Text(
            '로그인',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 4),
        FilledButton(
          onPressed: onSignUp,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: const Text('회원가입'),
        ),
      ],
    );
  }
}

class _RailActions extends StatelessWidget {
  const _RailActions({
    required this.onLogin,
    required this.onSignUp,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            onPressed: onLogin,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('로그인'),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onSignUp,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 6),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(fontSize: 11),
            ),
            child: const Text('가입'),
          ),
        ],
      ),
    );
  }
}

/// 비로그인 시 셸 제목
String seekerShellTitleForSession() =>
    SeekerShellAccess.isSignedInSeeker ? '구직자' : '둘러보기';
