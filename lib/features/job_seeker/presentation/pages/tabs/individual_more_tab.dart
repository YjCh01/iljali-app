import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/constants/app_strings.dart';
import 'package:map/core/widgets/mvp_feedback.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';

/// 구직자 6번 탭 — 프로필·설정 (↔ 기업 더보기)
class IndividualMoreTab extends StatelessWidget {
  const IndividualMoreTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthSession.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.memberGateway,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name ?? '구직자',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  AppStrings.platformDescription,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            icon: Icons.health_and_safety_outlined,
            title: '건강보험 재직 인증하기',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerHealthInsurance,
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: '푸시 알림',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerPushInbox,
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: '알림 설정',
            onTap: () => showMvpInfoSnackBar(context, '알림 설정'),
          ),
          _MenuTile(
            icon: Icons.bookmark_outline_rounded,
            title: '저장한 공고',
            onTap: () => showMvpInfoSnackBar(context, '저장한 공고'),
          ),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            title: '고객센터',
            onTap: () => showMvpInfoSnackBar(context, '고객센터'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _logout(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }
}
