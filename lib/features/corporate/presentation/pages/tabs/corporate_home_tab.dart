import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:map/core/compliance/services/subscription_renewal_service.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/utils/corporate_shell_access.dart';
import 'package:map/core/sync/member_sanction_guard.dart';
import 'package:map/core/widgets/push_wallet_bonus_feedback.dart';
import 'package:map/features/corporate/data/datasources/corporate_dashboard_local_data_source.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_dashboard_summary_usecase.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/presentation/pages/job_post_detail_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/closed_ghost_pin_callout_card.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_map_pin_callout_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_feature_highlights.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_map_background.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_stat_card.dart';

/// 기업회원 홈 — 지도 전체 + 당근형 드래그 시트
class CorporateHomeTab extends StatefulWidget {
  const CorporateHomeTab({
    super.key,
    this.onCreateJobPost,
    this.onSetupProfile,
    this.onOpenJobPosts,
    this.onOpenChat,
    this.focusPostId,
    this.focusPost,
    this.onFocusConsumed,
  });

  final VoidCallback? onCreateJobPost;
  final VoidCallback? onSetupProfile;
  final VoidCallback? onOpenJobPosts;
  final VoidCallback? onOpenChat;
  final String? focusPostId;
  final CorporateJobPost? focusPost;
  final VoidCallback? onFocusConsumed;

  @override
  State<CorporateHomeTab> createState() => _CorporateHomeTabState();
}

class _CorporateHomeTabState extends State<CorporateHomeTab> {
  static const _sheetSnapSizes = [0.26, 0.52, 0.92];

  final _getSummary = const GetCorporateDashboardSummaryUseCase(
    CorporateDashboardLocalDataSourceImpl(),
  );
  final _sheetController = DraggableScrollableController();

  CorporateDashboardSummary? _summary;
  bool _loading = true;
  JobMapPin? _calloutPin;

  @override
  void initState() {
    super.initState();
    AuthSession.instance.corporateProfileRevision
        .addListener(_onCorporateProfileChanged);
    _load();
    SubscriptionRenewalService().checkAndApplyExpiry().then((_) {
      if (mounted) _load();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSanctionNotices());
  }

  Future<void> _showSanctionNotices() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null || !mounted) return;
    await MemberSanctionGuard.showPendingNotices(context, email: email);
  }

  void _onCorporateProfileChanged() {
    if (mounted) _load();
  }

  void _closeCallout() {
    if (_calloutPin == null) return;
    setState(() => _calloutPin = null);
  }

  void _onSelectedPinChanged(JobMapPin? pin) {
    setState(() => _calloutPin = pin);
    if (pin != null && _sheetController.isAttached) {
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openDetailPreview(JobMapPin pin) {
    final isOwnPreview = _isOwnPin(pin);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => JobPostDetailPage(
          pin: pin,
          employerPreview: isOwnPreview,
          showActionGrid: false,
        ),
      ),
    );
  }

  bool _isOwnPin(JobMapPin pin) {
    final viewerKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    final ownerKey = pin.post.registeredBy?.companyKey;
    return viewerKey != null && ownerKey != null && viewerKey == ownerKey;
  }

  @override
  void didUpdateWidget(CorporateHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusPostId != null &&
        widget.focusPostId != oldWidget.focusPostId &&
        _sheetController.isAttached) {
      _sheetController.animateTo(
        0.18,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void dispose() {
    AuthSession.instance.corporateProfileRevision
        .removeListener(_onCorporateProfileChanged);
    _sheetController.dispose();
    super.dispose();
  }

  void _dragSheetByDelta(double deltaDy) {
    if (!_sheetController.isAttached) return;
    final height = MediaQuery.sizeOf(context).height;
    if (height <= 0) return;
    final next = (_sheetController.size - deltaDy / height).clamp(0.18, 0.92);
    _sheetController.jumpTo(next);
  }

  void _snapSheetToNextSize() {
    if (!_sheetController.isAttached) return;
    final current = _sheetController.size;
    final next = _sheetSnapSizes.firstWhere(
      (size) => size > current + 0.04,
      orElse: () => _sheetSnapSizes.first,
    );
    _sheetController.animateTo(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _sheetDragHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _snapSheetToNextSize,
        onVerticalDragUpdate: (details) => _dragSheetByDelta(details.delta.dy),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
          child: Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _load() async {
    try {
      final summary = await _getSummary();
      final profile = AuthSession.instance.currentUser?.corporateProfile;
      if (profile != null && profile.pushWallet == null) {
        final outcome = await PushWalletService().loadWalletDetailed(profile);
        if (mounted && outcome.grantedAnyBonus) {
          showPushWalletBonusSnackBar(context, outcome);
        }
      }
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('CorporateHomeTab._load failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _greetingLine() {
    if (!CorporateShellAccess.isSignedInCorporate) {
      return '채용 지도를 먼저 둘러보세요';
    }

    final user = AuthSession.instance.currentUser;
    final profile = user?.corporateProfile;
    final company = profile?.companyName.trim();
    if (company != null && company.isNotEmpty) {
      return '$company님, 안녕하세요';
    }
    return '${user?.name ?? '기업'}님, 안녕하세요';
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthSession.instance.currentUser;
    final summary = _summary;

    if (_loading || summary == null) {
      if (widget.focusPostId != null) {
        return Stack(
          fit: StackFit.expand,
          children: [
            CorporateHomeMapBackground(
              focusPostId: widget.focusPostId,
              focusPost: widget.focusPost,
              selectedPostId: _calloutPin?.post.id,
              onSelectedPinChanged: _onSelectedPinChanged,
              onFocusConsumed: widget.onFocusConsumed,
            ),
            const ColoredBox(
              color: Color(0x66FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        );
      }
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CorporateHomeMapBackground(
          focusPostId: widget.focusPostId,
          focusPost: widget.focusPost,
          selectedPostId: _calloutPin?.post.id,
          onSelectedPinChanged: _onSelectedPinChanged,
          onFocusConsumed: widget.onFocusConsumed,
        ),
        if (_calloutPin != null)
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.sizeOf(context).height * 0.38,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: JobMapPinCalloutCard.maxCompactWidth,
                ),
                child: _calloutPin!.isClosedGhost
                    ? ClosedGhostPinCalloutCard(
                        pin: _calloutPin!,
                        onClose: _closeCallout,
                      )
                    : JobMapPinCalloutCard(
                        pin: _calloutPin!,
                        compact: true,
                        employerPreview: _isOwnPin(_calloutPin!),
                        onClose: _closeCallout,
                        onViewDetail: () => _openDetailPreview(_calloutPin!),
                      ),
              ),
            ),
          ),
        DraggableScrollableSheet(
          controller: _sheetController,
          initialChildSize: _sheetSnapSizes.first,
          minChildSize: 0.18,
          maxChildSize: _sheetSnapSizes.last,
          snap: true,
          snapSizes: _sheetSnapSizes,
          builder: (context, scrollController) {
            return ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(22),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _sheetDragHandle(),
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: ClampingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                        children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '채용 현황',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _greetingLine(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (user?.isCorporate == true && user?.corporateProfile == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Material(
                        color: AppColors.primaryLight.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: widget.onSetupProfile,
                          borderRadius: BorderRadius.circular(14),
                          child: const Padding(
                            padding: EdgeInsets.all(14),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '기업·담당자 정보를 등록해 주세요',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  CorporateHomeFeatureHighlights(
                    onPushHiring: widget.onCreateJobPost ?? () {},
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CorporateStatCard(
                        key: const Key('corp-stat-job-posts'),
                        label: '진행 공고',
                        value: '${summary.activeJobPosts}',
                        icon: Icons.work_outline_rounded,
                        onTap: widget.onOpenJobPosts,
                      ),
                      const SizedBox(width: 10),
                      CorporateStatCard(
                        key: const Key('corp-stat-unread-chats'),
                        label: '안 읽은 채팅',
                        value: '${summary.unreadChats}',
                        icon: Icons.mark_chat_unread_outlined,
                        onTap: widget.onOpenChat,
                      ),
                    ],
                  ),
                  if (summary.activeJobs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      '진행 중 공고',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...summary.activeJobs.map(
                      (job) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _JobListTile(
                          title: job.title,
                          subtitle: '지원 ${job.applicantCount}명',
                          trailing: job.statusLabel,
                          onTap: widget.onOpenJobPosts,
                        ),
                      ),
                    ),
                  ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _JobListTile extends StatelessWidget {
  const _JobListTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                trailing,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
