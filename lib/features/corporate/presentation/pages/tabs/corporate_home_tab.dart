import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/compliance/services/subscription_renewal_service.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/datasources/corporate_dashboard_local_data_source.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_dashboard_summary_usecase.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_exposure_map.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_feature_highlights.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_stat_card.dart';

/// 기업회원 홈 — 대시보드 (1번 탭)
class CorporateHomeTab extends StatefulWidget {
  const CorporateHomeTab({
    super.key,
    this.onCreateJobPost,
    this.onSetupProfile,
    this.onReviewApplicants,
    this.onOpenJobPosts,
    this.onOpenApplicants,
    this.onOpenAttendance,
    this.onOpenChat,
    this.onOpenPackageShop,
  });

  final VoidCallback? onCreateJobPost;
  final VoidCallback? onSetupProfile;
  final VoidCallback? onReviewApplicants;
  final VoidCallback? onOpenJobPosts;
  final VoidCallback? onOpenApplicants;
  final VoidCallback? onOpenAttendance;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenPackageShop;

  @override
  State<CorporateHomeTab> createState() => _CorporateHomeTabState();
}

class _CorporateHomeTabState extends State<CorporateHomeTab> {
  final _getSummary = const GetCorporateDashboardSummaryUseCase(
    CorporateDashboardLocalDataSourceImpl(),
  );

  CorporateDashboardSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    SubscriptionRenewalService().checkAndApplyExpiry().then((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    final summary = await _getSummary();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final summary = _summary;

    return ColoredBox(
      color: AppColors.background,
      child: _loading || summary == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${user?.name ?? '기업'}님, 안녕하세요',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (user?.corporateProfile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${user!.corporateProfile!.companyName} · '
                      '담당자 코드 ${user.corporateProfile!.handlerCode}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                  if (user?.isCorporate == true && user?.corporateProfile == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Material(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: widget.onSetupProfile,
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.business_outlined,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '기업·담당자 정보를 등록해 주세요',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        '공고 결제 보고서·담당자 코드 발급에 필요합니다.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.95),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    ProductFeatureFlags.isPermanentHireEnabled
                        ? '일용직·상시직 종합 일자리 매칭'
                        : '일용직 현장 채용 · 물류·식품 공장',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                  const SizedBox(height: 20),
                  CorporateHomeExposureMap(),
                  const SizedBox(height: 12),
                  CorporateHomeFeatureHighlights(
                    onPushHiring: widget.onCreateJobPost ?? () {},
                    onInstantMatching:
                        widget.onOpenPackageShop ?? widget.onOpenApplicants ?? () {},
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      CorporateStatCard(
                        label: '진행 공고',
                        value: '${summary.activeJobPosts}',
                        icon: Icons.work_outline_rounded,
                        onTap: widget.onOpenJobPosts,
                      ),
                      const SizedBox(width: 10),
                      CorporateStatCard(
                        label: '오늘 지원',
                        value: '${summary.newApplicantsToday}',
                        icon: Icons.person_add_alt_1_outlined,
                        onTap: widget.onOpenApplicants,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      CorporateStatCard(
                        label: '오늘 출근율',
                        value: '${summary.todayAttendanceRate}',
                        suffix: '%',
                        icon: Icons.fact_check_outlined,
                        onTap: widget.onOpenAttendance,
                      ),
                      const SizedBox(width: 10),
                      CorporateStatCard(
                        label: '안 읽은 채팅',
                        value: '${summary.unreadChats}',
                        icon: Icons.mark_chat_unread_outlined,
                        onTap: widget.onOpenChat,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const _SectionHeader(
                    title: '빠른 작업',
                    actionLabel: null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.post_add_outlined,
                          label: '공고 등록',
                          onTap: widget.onCreateJobPost ?? () {},
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _QuickActionButton(
                          icon: Icons.how_to_reg_outlined,
                          label: '지원자 검토',
                          onTap: widget.onReviewApplicants ?? () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionHeader(
                    title: '최근 지원자',
                    actionLabel: '전체보기',
                    onActionTap: widget.onOpenApplicants,
                  ),
                  const SizedBox(height: 10),
                  ...summary.recentApplicants.map(
                    (applicant) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListTileCard(
                        title: applicant.name,
                        subtitle: applicant.jobTitle,
                        trailing: applicant.appliedAtLabel,
                        onTap: widget.onOpenApplicants,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(
                    title: '진행 중 공고',
                    actionLabel: '관리',
                    onActionTap: widget.onOpenJobPosts,
                  ),
                  const SizedBox(height: 10),
                  ...summary.activeJobs.map(
                    (job) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ListTileCard(
                        title: job.title,
                        subtitle: '지원 ${job.applicantCount}명',
                        trailing: job.statusLabel,
                        trailingColor: AppColors.primary,
                        onTap: widget.onOpenJobPosts,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ListTileCard extends StatelessWidget {
  const _ListTileCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.trailingColor,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Color? trailingColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: trailingColor ?? AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
