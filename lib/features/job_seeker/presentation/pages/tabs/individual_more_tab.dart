import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/work_category/domain/entities/seeker_work_achievement.dart';
import 'package:map/features/work_category/domain/services/work_achievement_service.dart';
import 'package:map/features/work_category/presentation/widgets/seeker_work_achievement_preview_row.dart';

/// 구직자 6번 탭 — 프로필·설정
class IndividualMoreTab extends StatefulWidget {
  const IndividualMoreTab({super.key, this.onOpenVaultTab});

  final VoidCallback? onOpenVaultTab;

  @override
  State<IndividualMoreTab> createState() => _IndividualMoreTabState();
}

class _IndividualMoreTabState extends State<IndividualMoreTab> {
  SeekerWorkAchievementSummary? _achievements;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  Future<void> _loadAchievements() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;
    final summary = await WorkAchievementService().loadSummary(email);
    if (!mounted) return;
    setState(() => _achievements = summary);
  }

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
                if (_achievements != null) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  const Text(
                    '내 업무 업적',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SeekerWorkAchievementPreviewRow(
                    summary: _achievements!,
                    onTapViewAll: () async {
                      await Navigator.of(context).pushNamed(
                        AppRoutes.seekerWorkAchievements,
                      );
                      if (mounted) _loadAchievements();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _MenuTile(
            icon: Icons.emoji_events_outlined,
            title: '업무 업적 전체 보기',
            onTap: () async {
              await Navigator.of(context).pushNamed(
                AppRoutes.seekerWorkAchievements,
              );
              if (mounted) _loadAchievements();
            },
          ),
          _MenuTile(
            icon: Icons.badge_outlined,
            title: '신분증·통장 등록',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerMyDocuments,
            ),
          ),
          _MenuTile(
            icon: Icons.health_and_safety_outlined,
            title: '건강보험 재직 인증하기',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerHealthInsurance,
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'PUSH 알림',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerPushInbox,
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: '알림 설정',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.seekerNotificationSettings,
            ),
          ),
          _MenuTile(
            icon: Icons.bookmark_outline_rounded,
            title: '나의 보관함',
            onTap: widget.onOpenVaultTab ?? () {},
          ),
          _MenuTile(
            icon: Icons.help_outline_rounded,
            title: '고객센터',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.customerSupport,
            ),
          ),
          _MenuTile(
            icon: Icons.description_outlined,
            title: '약관 및 정책',
            onTap: () => Navigator.of(context).pushNamed(
              AppRoutes.legalDocuments,
            ),
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
