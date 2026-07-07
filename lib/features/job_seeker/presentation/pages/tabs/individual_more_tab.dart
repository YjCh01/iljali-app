import 'package:flutter/material.dart';
import 'package:map/core/auth/guest_auth_navigation.dart';
import 'package:map/core/branding/iljari_ad_campaign.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/legal/widgets/business_disclosure_footer.dart';
import 'package:map/features/auth/data/local/local_individual_auth_store.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/presentation/widgets/bus_location_tower_pilot_entry_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_readiness.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_login_prompt_sheet.dart';

/// 구직자 5번 탭 — 프로필·설정
class IndividualMoreTab extends StatelessWidget {
  const IndividualMoreTab({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthSession.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (_) => false,
    );
  }

  Future<void> _requireLogin(
    BuildContext context, {
    required VoidCallback onSignedIn,
    String? message,
  }) async {
    if (SeekerShellAccess.isSignedInSeeker) {
      onSignedIn();
      return;
    }
    await SeekerLoginPromptSheet.show(context, message: message);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final signedIn = SeekerShellAccess.isSignedInSeeker;

    return ColoredBox(
      color: AppColors.background,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const IljariAdCampaignBanner(),
          const SizedBox(height: 16),
          CorporateSurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  signedIn ? (user?.name ?? '구직자') : '로그인하고 일자리를 지원해 보세요',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (signedIn && user?.email != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user!.email,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
                if (!signedIn) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => GuestAuthNavigation.openLogin(context),
                    child: const Text('로그인'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => GuestAuthNavigation.openSignUp(context),
                    child: const Text('회원가입'),
                  ),
                ],
              ],
            ),
          ),
          if (signedIn &&
              !SeekerProfileReadiness.isMatchingReady(
                user?.seekerProfile,
                displayName: user?.name,
              )) ...[
            const SizedBox(height: 12),
            CorporateSurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '프로필 완성하기',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '실주소·근무지역·스케줄을 등록하면 공고 지원과 매칭이 가능합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppRoutes.seekerProfileOnboarding,
                    ),
                    child: const Text('2단계 프로필 입력'),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (signedIn) const BusLocationTowerPilotEntryCard(),
          _MenuTile(
            icon: Icons.home_outlined,
            title: '실주소',
            onTap: () => _requireLogin(
              context,
              onSignedIn: () => Navigator.of(context).pushNamed(
                AppRoutes.seekerHomeAddress,
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.article_outlined,
            title: '내 이력서',
            onTap: () => _requireLogin(
              context,
              message: '내 이력서는 개인회원 로그인 후 작성·확인할 수 있습니다.',
              onSignedIn: () => Navigator.of(context).pushNamed(
                AppRoutes.seekerMyResume,
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.verified_outlined,
            title: '자격·면허 등록',
            onTap: () => _requireLogin(
              context,
              onSignedIn: () => Navigator.of(context).pushNamed(
                AppRoutes.seekerMyCredentials,
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.badge_outlined,
            title: '신분증·통장 등록',
            onTap: () => _requireLogin(
              context,
              onSignedIn: () => Navigator.of(context).pushNamed(
                AppRoutes.seekerMyDocuments,
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'PUSH 알림',
            onTap: () => _requireLogin(
              context,
              onSignedIn: () => Navigator.of(context).pushNamed(
                AppRoutes.seekerPushInbox,
              ),
            ),
          ),
          _MenuTile(
            icon: Icons.notifications_outlined,
            title: '알림 설정',
            onTap: () => _requireLogin(
              context,
              onSignedIn: () => Navigator.of(context).pushNamed(
                AppRoutes.seekerNotificationSettings,
              ),
            ),
          ),
          if (signedIn) const _ProposalOffersToggle(),
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
          const SizedBox(height: 16),
          const BusinessDisclosureFooter(),
          if (signedIn) ...[
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
        ],
      ),
    );
  }
}

class _ProposalOffersToggle extends StatefulWidget {
  const _ProposalOffersToggle();

  @override
  State<_ProposalOffersToggle> createState() => _ProposalOffersToggleState();
}

class _ProposalOffersToggleState extends State<_ProposalOffersToggle> {
  bool _saving = false;

  bool get _enabled =>
      AuthSession.instance.currentUser?.seekerProfile?.proposalOffersAccepted ??
      true;

  Future<void> _setEnabled(bool value) async {
    final user = AuthSession.instance.currentUser;
    final profile = user?.seekerProfile;
    if (user == null || profile == null || _saving) return;

    setState(() => _saving = true);
    final updated = profile.copyWith(proposalOffersAccepted: value);
    await AuthSession.instance.updateSeekerProfile(updated);
    await LocalIndividualAuthStore.updateSeekerProfile(
      email: user.email,
      seekerProfile: updated,
    );
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: CorporateSurfaceCard(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            '기업 채용 제안 수신',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '인재 검색에 노출되고 기업이 공고와 함께 제안을 보낼 수 있습니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          value: _enabled,
          onChanged: _saving ? null : _setEnabled,
          activeThumbColor: AppColors.primary,
        ),
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
