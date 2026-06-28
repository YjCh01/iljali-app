import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/constants/app_routes.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/core/session/auth_session.dart';

import 'package:map/core/widgets/transient_snack_bar.dart';

import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

import 'package:map/features/corporate/data/repositories/local_push_usage_repository.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_service.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/utils/extra_push_availability.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_edit_job_post_args.dart';
import 'package:map/features/corporate/presentation/navigation/corporate_job_post_flow_result.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_create_job_post_entry_sheet.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_post_services_guide.dart';
import 'package:map/features/corporate/presentation/widgets/push_target_select_sheet.dart';

import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_optional_services_sheet.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_target_resolver.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';
import 'package:map/features/corporate/domain/usecases/save_corporate_job_post_usecase.dart';



/// 기업회원 2번 탭 — 공고 관리

class CorporateJobPostsTab extends StatefulWidget {
  const CorporateJobPostsTab({
    super.key,
    this.onViewApplicants,
    this.onViewPostOnMap,
  });

  final void Function(CorporateJobPost post)? onViewApplicants;
  final void Function(CorporateJobPost post)? onViewPostOnMap;

  @override
  State<CorporateJobPostsTab> createState() => _CorporateJobPostsTabState();
}



class _CorporateJobPostsTabState extends State<CorporateJobPostsTab> {

  static const _dataSource = CorporateJobPostLocalDataSourceImpl();

  final _getJobPosts = const GetCorporateJobPostsUseCase(_dataSource);
  final _reactivateJobPost = const ReactivateCorporateJobPostUseCase(_dataSource);
  final _closeJobPost = const CloseCorporateJobPostUseCase(_dataSource);
  final _duplicateJobPost = const DuplicateCorporateJobPostUseCase(_dataSource);
  final _scrollController = ScrollController();
  final _shopGridKey = GlobalKey();



  List<CorporateJobPost> _posts = [];

  EmployerPushWallet? _wallet;

  bool _loading = true;
  String? _loadError;



  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final profile = AuthSession.instance.currentUser?.corporateProfile;
      EmployerPushWallet? wallet;
      var posts = await _getJobPosts();
      if (profile != null) {
        wallet = profile.pushWallet ??
            await PushWalletService().loadWallet(profile);
        final postsToPersist = <CorporateJobPost>[];
        posts = posts
            .map((post) {
              final settings = post.notificationSettings;
              if (settings == null) return post;
              final synced = settings.copyWith(
                basePoints: ExposureSlotPolicy.syncPaidRecruitmentActivations(
                  settings.basePoints,
                ),
              );
              final clamped = PushWalletCreditPolicy.clampNotificationSettings(
                synced,
                wallet!,
              );
              if (!_notificationSettingsChanged(settings, clamped)) return post;
              final healed = post.copyWith(notificationSettings: clamped);
              postsToPersist.add(healed);
              return healed;
            })
            .toList(growable: false);

        for (final healed in postsToPersist) {
          await _dataSource.updateJobPost(
            healed,
            ownerCompanyKey: profile.companyKey,
          );
        }
        if (postsToPersist.isNotEmpty) {
          JobBoardRefresh.markUpdated();
        }
      }

      if (!mounted) return;
      setState(() {
        _posts = posts;
        _wallet = wallet;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('CorporateJobPostsTab._load failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = '공고 목록을 불러오지 못했습니다.';
      });
    }
  }

  /// 이용권으로 추가됐으나 노출 활성화 플래그만 누락된 일자리 알림핀 복구
  Future<CorporateJobPost> _ensureHealedPinActivations(
    CorporateJobPost post,
  ) async {
    final settings = post.notificationSettings;
    if (settings == null) return post;

    final syncedPoints = ExposureSlotPolicy.syncPaidRecruitmentActivations(
      settings.basePoints,
    );
    final healedSettings = settings.copyWith(basePoints: syncedPoints);
    if (!_notificationSettingsChanged(settings, healedSettings)) return post;

    final healed = post.copyWith(notificationSettings: healedSettings);
    final ownerKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    await _dataSource.updateJobPost(
      healed,
      ownerCompanyKey: ownerKey,
    );
    JobBoardRefresh.markUpdated();
    if (mounted) {
      setState(() {
        _posts = _posts
            .map((p) => p.id == healed.id ? healed : p)
            .toList(growable: false);
      });
    }
    return healed;
  }

  static bool _notificationSettingsChanged(
    JobPostNotificationSettings? before,
    JobPostNotificationSettings? after,
  ) {
    if (before == null && after == null) return false;
    if (before == null || after == null) return true;
    if (before.basePoints.length != after.basePoints.length) return true;
    for (var i = 0; i < before.basePoints.length; i++) {
      final a = before.basePoints[i];
      final b = after.basePoints[i];
      if (a.exposureActivated != b.exposureActivated ||
          a.activationCoordinate != b.activationCoordinate) {
        return true;
      }
    }
    return false;
  }



  Future<void> _openCreate() async {
    final flowResult =
        await Navigator.of(context).pushNamed<CorporateJobPostFlowResult>(
      AppRoutes.corporateCreateJobPost,
    );
    if (flowResult != null) {
      JobBoardRefresh.markUpdated();
      await _load();
    }
  }

  Future<void> _openImport() async {
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateJobPostImport,
    );
    if (created == true) {
      JobBoardRefresh.markUpdated();
      await _load();
    }
  }



  Future<void> _openEditPicker() async {

    final updated = await Navigator.of(context).pushNamed(

      AppRoutes.corporateSelectJobPost,

    );

    if (updated == true) await _load();

  }



  Future<void> _editPost(CorporateJobPost post) async {

    final updated = await Navigator.of(context).pushNamed<bool>(

      AppRoutes.corporateEditJobPost,

      arguments: post,

    );

    if (updated == true) {

      JobBoardRefresh.markUpdated();

      await _load();

    }

  }

  Future<void> _copyPost(CorporateJobPost post) async {
    final created = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporateEditJobPost,
      arguments: CorporateEditJobPostArgs(post: post, asCopy: true),
    );
    if (created == true) {
      JobBoardRefresh.markUpdated();
      await _load();
    }
  }

  Future<void> _closePost(CorporateJobPost post) async {
    if (post.status == CorporateJobPostStatus.closed) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('공고 마감'),
        content: Text('「${post.title}」 공고를 마감하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('마감'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _closeJobPost(post);
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '공고를 마감하지 못했습니다.')),
      );
      return;
    }

    JobBoardRefresh.markUpdated();
    await _load();
  }

  Future<void> _repostJob(CorporateJobPost post) async {
    if (post.status == CorporateJobPostStatus.closed) return;

    final result = await _duplicateJobPost(post);
    if (!mounted) return;
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '공고를 재등록하지 못했습니다.')),
      );
      return;
    }

    JobBoardRefresh.markUpdated();
    await _load();
    if (!mounted) return;
    showTransientSnackBar(context, '동일한 공고가 새로 등록되었습니다.');
  }



  Future<void> _deletePost(CorporateJobPost post) async {
    final confirmed = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: const Text('공고 삭제'),

        content: Text(

          '「${post.title}」 공고를 삭제하시겠습니까?\n'

          '삭제 후에는 복구할 수 없습니다.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.of(context).pop(false),

            child: const Text('취소'),

          ),

          FilledButton(

            onPressed: () => Navigator.of(context).pop(true),

            style: FilledButton.styleFrom(

              backgroundColor: const Color(0xFFC62828),

            ),

            child: const Text('삭제'),

          ),

        ],

      ),

    );

    if (confirmed != true || !mounted) return;



    final ownerKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    final deleted = await _dataSource.deleteJobPost(
      post.id,
      ownerCompanyKey: ownerKey,
    );

    if (!mounted) return;

    if (!deleted) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('공고를 삭제하지 못했습니다.')),

      );

      return;

    }



    JobBoardRefresh.markUpdated();

    await _load();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(content: Text('공고가 삭제되었습니다.')),

    );

  }

  Future<void> _reactivateWorkplace(CorporateJobPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('공고를 재등록하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('예'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _reactivateJobPost(post);
    if (!mounted) return;

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '공고를 재등록하지 못했습니다.'),
        ),
      );
      return;
    }

    JobBoardRefresh.markUpdated();
    await _load();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('공고가 재등록되었습니다.')),
    );
  }



  Future<void> _sendRecruitPush(
    CorporateJobPost post, {
    required List<PushDispatchTarget> targets,
    required PushTargetPaymentMode paymentMode,
  }) async {
    if (targets.isEmpty) return;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기업 프로필이 없어 PUSH를 보낼 수 없습니다.')),
      );
      return;
    }

    final prepared = targets.length == 1
        ? await PushDispatchService().prepareTargetedDispatch(
            context: context,
            profile: profile,
            post: post,
            target: targets.first,
            paymentMode: paymentMode,
          )
        : await PushDispatchService().prepareBatchTargetedDispatch(
            context: context,
            profile: profile,
            post: post,
            targets: targets,
            paymentMode: paymentMode,
          );
    if (!mounted) return;
    if (prepared == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PUSH 발송을 완료하지 못했습니다.')),
      );
      return;
    }

    final targetLabel = targets.map((t) => t.title).join(' · ');
    final slotCount = paymentMode == PushTargetPaymentMode.comboIncluded
        ? 1
        : targets.length;

    await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushDispatch,
      arguments: PushDispatchArgs(
        radiusTier: prepared.radiusTier,
        recruitmentSlotCount: slotCount,
        jobPostId: post.id,
        jobTitle: post.title,
        companyName: profile.companyName,
        targetLabel: targetLabel,
        targetKind: targets.first.kind,
        reachSeed: targets.fold<int>(
          0,
          (seed, t) =>
              seed ^
              t.coordinate.latitude.hashCode ^
              t.coordinate.longitude.hashCode,
        ),
      ),
    );

    final usageRepo = await LocalPushUsageRepository.create();
    await usageRepo.recordDispatch(
      companyKey: profile.companyKey,
      paymentKrw: prepared.paymentKrw,
    );

    if (!mounted) return;
    final feeLabel = switch (paymentMode) {
      PushTargetPaymentMode.comboIncluded => ' (노출+PUSH 포함)',
      PushTargetPaymentMode.walletCredit =>
        ' (PUSH 알림권 ${targets.length}회)',
      PushTargetPaymentMode.pgPayment =>
        ' (${PushTicketCatalog.unitPriceLabel} × ${targets.length})',
    };
    final locationLabel =
        targets.length == 1 ? '「${targets.first.title}」' : '${targets.length}곳';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$locationLabel PUSH가 전송되었습니다.$feeLabel')),
    );

    await _load();
  }

  void _viewPost(CorporateJobPost post) {
    final onMap = widget.onViewPostOnMap;
    if (onMap != null) {
      onMap(post);
      return;
    }
  }

  Future<void> _openPaidServices(CorporateJobPost post) async {
    final fresh = await _dataSource.findById(post.id) ?? post;
    if (!mounted) return;
    await showCorporateJobPostOptionalServicesSheet(
      context,
      post: fresh,
      onPostUpdated: (_) async {
        JobBoardRefresh.markUpdated();
        await _load();
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _manageExpansion(CorporateJobPost post) async {
    await _openPaidServices(post);
  }

  Future<void> _configureExposure(CorporateJobPost post) async {
    await _openPaidServices(post);
  }

  Future<void> _recruit(CorporateJobPost post) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기업 프로필이 없어 PUSH를 보낼 수 없습니다.')),
      );
      return;
    }

    post = await _ensureHealedPinActivations(post);

    final routeId = post.commuteRouteId?.trim();
    CommuteRoute? route;
    if (routeId != null && routeId.isNotEmpty) {
      final repo = await CommuteRouteRepository.create();
      route = await repo.findById(routeId);
    }

    final targets = PushDispatchTargetResolver.resolve(
      post: post,
      commuteRoute: route,
    );

    if (!mounted) return;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '발송 대상이 없습니다. 알림핀·거점 또는 셔틀 노선을 먼저 설정해 주세요.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selection = await showPushTargetSelectSheet(
      context,
      targets: targets,
      pushTicketCredits: _wallet?.pushTicketCredits ?? 0,
      post: post,
    );
    if (!mounted || selection == null) return;

    await _sendRecruitPush(
      post,
      targets: selection.targets,
      paymentMode: selection.paymentMode,
    );
  }

  Future<void> _scrollToShopGrid() async {
    final context = _shopGridKey.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              : _posts.isEmpty
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    const _EmptyJobPostsHint(),
                    const SizedBox(height: 20),
                    CorporateCreateJobPostEntryPanel(
                      onWrite: _openCreate,
                      onImport: _openImport,
                    ),
                  ],
                )
              : ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                CorporateCreateJobPostEntryPanel(
                  onWrite: _openCreate,
                  onImport: _openImport,
                ),
                const SizedBox(height: 16),
                for (var i = 0; i < _posts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final post = _posts[i];
                      final availability = ExtraPushAvailability.resolve(
                        post: post,
                        wallet: _wallet,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CorporateJobPostCard(
                            post: post,
                            extraPushAvailability: availability,
                            onView: () => _viewPost(post),
                            onEdit: () => _editPost(post),
                            onDelete: () => _deletePost(post),
                            onClose: post.status == CorporateJobPostStatus.closed
                                ? null
                                : () => _closePost(post),
                            onCopy: () => _copyPost(post),
                            onRepost: () => _repostJob(post),
                            onConfigureExposure: () => _configureExposure(post),
                            onManageExpansion: () => _manageExpansion(post),
                            onReactivateWorkplace: () => _reactivateWorkplace(post),
                            onRecruit: () => _recruit(post),
                            onApplicantsTap: post.applicantCount > 0
                                ? () => widget.onViewApplicants?.call(post)
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),
                Material(
                  key: _shopGridKey,
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.searchBarBorder),
                    ),
                    child: const CorporatePostServicesGuide(),
                  ),
                ),
              ],
            ),

    );

  }

}



class _EmptyJobPostsHint extends StatelessWidget {
  const _EmptyJobPostsHint();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(
            Icons.article_outlined,
            size: 44,
            color: AppColors.primaryLight.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 12),
          const Text(
            '등록된 공고가 없습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}


