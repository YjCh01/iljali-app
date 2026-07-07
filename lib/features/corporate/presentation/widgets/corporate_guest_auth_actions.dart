import 'package:flutter/material.dart';
import 'package:map/core/auth/guest_auth_navigation.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/presentation/utils/corporate_shell_access.dart';

enum CorporateGuestAuthLayout { appBar, topBar, rail }

/// 비로그인 기업 — 로그인·가입 진입
class CorporateGuestAuthActions extends StatelessWidget {
  const CorporateGuestAuthActions({
    super.key,
    this.layout = CorporateGuestAuthLayout.appBar,
  });

  final CorporateGuestAuthLayout layout;

  void _openLogin(BuildContext context) => GuestAuthNavigation.openLogin(context);

  void _openSignUp(BuildContext context) => GuestAuthNavigation.openSignUp(context);

  @override
  Widget build(BuildContext context) {
    if (CorporateShellAccess.isSignedInCorporate) {
      return const SizedBox.shrink();
    }

    return switch (layout) {
      CorporateGuestAuthLayout.appBar => _AppBarActions(
          onLogin: () => _openLogin(context),
          onSignUp: () => _openSignUp(context),
        ),
      CorporateGuestAuthLayout.topBar => _TopBarActions(
          onLogin: () => _openLogin(context),
          onSignUp: () => _openSignUp(context),
        ),
      CorporateGuestAuthLayout.rail => _RailActions(
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
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.publicPricing),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          child: const Text(
            '요금',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
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

String corporateShellTitleForSession() =>
    CorporateShellAccess.isSignedInCorporate ? '기업' : '둘러보기';
