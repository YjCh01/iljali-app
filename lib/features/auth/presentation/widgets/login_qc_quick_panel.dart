import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/dev/dev_auth_service.dart';
import 'package:map/core/dev/dev_test_accounts.dart';
import 'package:map/core/dev/qc_auth_service.dart';
import 'package:map/core/session/member_type.dart';

/// 로그인 화면 하단 — QC·개발 테스트 계정 원터치 로그인
class LoginQcQuickPanel extends StatefulWidget {
  const LoginQcQuickPanel({
    super.key,
    required this.memberType,
  });

  final MemberType memberType;

  @override
  State<LoginQcQuickPanel> createState() => _LoginQcQuickPanelState();
}

class _LoginQcQuickPanelState extends State<LoginQcQuickPanel> {
  bool _signingIn = false;

  bool get _visible =>
      kDebugMode && (EnvConfig.qcMode || DevAuthService.isEnabled);

  Future<void> _finishSignIn(Future<void> Function() action) async {
    if (_signingIn) return;
    setState(() => _signingIn = true);
    try {
      await action();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('테스트 로그인 실패: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signInDev(DevTestAccount account) {
    return _finishSignIn(() => DevAuthService.signIn(account));
  }

  Future<void> _signInQcSeeker() {
    return _finishSignIn(
      () => QcAuthService.signInSeeker(
        email: 'seeker-0001@qc.iljari.co.kr',
        password: QcAuthService.qcSeekerPassword,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    final isCorporate = widget.memberType == MemberType.corporate;
    final devAccounts = DevTestAccounts.all
        .where((account) => account.memberType == widget.memberType)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isCorporate ? 'QC · 개발 테스트 (기업)' : 'QC · 개발 테스트 (개인)',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        if (!isCorporate && QcAuthService.isQcSeekerEmailEnabled)
          _QuickLoginButton(
            busy: _signingIn,
            icon: Icons.badge_outlined,
            title: 'QC 구직자 0001',
            subtitle: 'seeker-0001@qc.iljari.co.kr',
            badge: QcAuthService.qcSeekerPassword,
            onTap: _signInQcSeeker,
          ),
        ...devAccounts.map(
          (account) => Padding(
            padding: const EdgeInsets.only(top: 6),
            child: _QuickLoginButton(
              busy: _signingIn,
              icon: isCorporate
                  ? Icons.business_center_outlined
                  : Icons.person_outline,
              title: account.label,
              subtitle: account.email,
              badge: account.password,
              onTap: () => _signInDev(account),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickLoginButton extends StatelessWidget {
  const _QuickLoginButton({
    required this.busy,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final bool busy;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: busy ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(icon, size: 20, color: Colors.white70),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
