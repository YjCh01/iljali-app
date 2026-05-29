import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/constants/app_routes.dart';

import 'package:map/core/job_board/job_board_refresh.dart';

import 'package:map/core/session/auth_session.dart';

import 'package:map/core/widgets/empty_state_card.dart';

import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

import 'package:map/features/corporate/data/repositories/local_push_usage_repository.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_service.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/utils/extra_push_availability.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';
import 'package:map/features/corporate/presentation/widgets/push_package_quick_shop_grid.dart';

import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_job_post_speed_dial.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_job_post_preview_sheet.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';
import 'package:map/features/corporate/presentation/widgets/extra_push_confirm_sheet.dart';



/// 기업회원 2번 탭 — 공고 관리

class CorporateJobPostsTab extends StatefulWidget {
  const CorporateJobPostsTab({
    super.key,
    this.onViewApplicants,
  });

  final void Function(CorporateJobPost post)? onViewApplicants;

  @override
  State<CorporateJobPostsTab> createState() => _CorporateJobPostsTabState();
}



class _CorporateJobPostsTabState extends State<CorporateJobPostsTab> {

  static const _dataSource = CorporateJobPostLocalDataSourceImpl();

  final _getJobPosts = const GetCorporateJobPostsUseCase(_dataSource);
  final _scrollController = ScrollController();
  final _shopGridKey = GlobalKey();



  List<CorporateJobPost> _posts = [];

  EmployerPushWallet? _wallet;

  bool _loading = true;



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

    setState(() => _loading = true);

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    EmployerPushWallet? wallet;
    var posts = await _getJobPosts();
    if (profile != null) {
      wallet = await PushWalletService().loadWallet(profile);
      posts = posts
          .map((post) {
            final settings = post.notificationSettings;
            if (settings == null) return post;
            final clamped = PushWalletCreditPolicy.clampNotificationSettings(
              settings,
              wallet!,
            );
            if (identical(clamped, settings)) return post;
            return post.copyWith(notificationSettings: clamped);
          })
          .toList(growable: false);
    }

    if (!mounted) return;

    setState(() {

      _posts = posts;

      _wallet = wallet;

      _loading = false;

    });

  }



  Future<void> _openCreate() async {

    final created = await Navigator.of(context).pushNamed(

      AppRoutes.corporateCreateJobPost,

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



    final deleted = await _dataSource.deleteJobPost(post.id);

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



  Future<void> _sendRecruitPush(CorporateJobPost post) async {
    final settings = post.notificationSettings;

    if (settings?.hasConfiguredBase != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 「모집지역 설정」을 완료해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final radiusTier = settings!.primaryBase?.radiusTier;
    if (radiusTier == null || radiusTier == PushRadiusTier.radius0km) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('노출 반경이 0km인 공고는 모집할 수 없습니다.')),
      );
      return;
    }

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기업 프로필이 없어 푸시를 보낼 수 없습니다.')),
      );
      return;
    }

    final prepared = await PushDispatchService().prepareQuickRecruitPush(
      context: context,
      profile: profile,
      settings: settings,
    );
    if (!mounted) return;
    if (prepared == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모집하기를 완료하지 못했습니다.')),
      );
      return;
    }

    await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushDispatch,
      arguments: PushDispatchArgs(
        radiusTier: prepared.radiusTier,
        recruitmentSlotCount: prepared.recruitmentPushCount.clamp(1, 999),
      ),
    );

    final usageRepo = await LocalPushUsageRepository.create();
    await usageRepo.recordDispatch(
      companyKey: profile.companyKey,
      paymentKrw: prepared.paymentKrw,
    );

    if (!mounted) return;
    final feeLabel = prepared.paymentKrw > 0
        ? ' (${PushPackageCatalog.krwSuffix(prepared.paymentKrw)} 결제)'
        : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('모집 알림이 전송되었습니다.$feeLabel')),
    );

    await _load();
  }

  Future<void> _viewPost(CorporateJobPost post) async {
    await showCorporateJobPostPreviewSheet(context, post);
  }

  Future<void> _configureExposure(CorporateJobPost post) async {
    final credits = _wallet?.packageRecruitCredits ?? 0;
    final confirmed = await showExtraPushConfirmSheet(
      context,
      post: post,
      availablePushCredits: credits,
      mode: ExtraPushSheetMode.configureZones,
    );
    if (!mounted || confirmed == null) return;

    final points = confirmed.updatedBasePoints;
    if (points == null || points.isEmpty) return;

    final maxPoints = _wallet == null
        ? points.length
        : PushWalletCreditPolicy.effectiveMaxExposurePoints(
            wallet: _wallet!,
            currentPointsLength: points.length,
          );
    final settings = JobPostNotificationSettings(
      basePoints: points.take(maxPoints).toList(growable: false),
      pushCountLimit: PushPlanEnforcement.dailyPushLimit,
      maxBasePointsAllowed: maxPoints,
      paymentCompleted: points.length <= PushPackageCatalog.baseLocationSlots,
      designatedPointTier: DesignatedPointTier.onePoint,
      spotPaymentCompleted:
          points.length <= PushPackageCatalog.baseLocationSlots,
    );

    await _dataSource.updateJobPost(
      post.copyWith(notificationSettings: settings),
    );
    JobBoardRefresh.markUpdated();
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('모집지역이 저장되었습니다. 「모집하기」로 알림을 보낼 수 있습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _recruit(CorporateJobPost post) async {
    final availability = ExtraPushAvailability.resolve(
      post: post,
      wallet: _wallet,
    );

    if (!availability.canDispatchRecruit) {
      if (!mounted) return;
      if (availability.needsExposureSetup) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('먼저 「모집지역 설정」을 완료해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (availability.reason == ExtraPushDisableReason.creditsExhausted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('지역 푸시권이 부족합니다. 「지역 푸시권 충전」 또는 아래 상품을 이용해 주세요.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _scrollToShopGrid();
      }
      return;
    }

    await _sendRecruitPush(post);
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

  String _shopGridMessage() {
    final wallet = _wallet;
    if (wallet != null && !wallet.hasUsablePush) {
      return '지역 푸시권을 모두 사용했습니다. 아래에서 바로 충전할 수 있습니다.';
    }
    final needsSettings = _posts.any(
      (post) =>
          ExtraPushAvailability.resolve(post: post, wallet: wallet)
              .needsExposureSetup,
    );
    if (needsSettings && wallet != null && wallet.hasUsablePush) {
      return '지역 푸시권이 충전되었습니다. 「모집지역 설정」 후 「모집하기」를 눌러 주세요.';
    }
    if (needsSettings) {
      return '노출 범위가 없는 공고는 모집할 수 없습니다. '
          '노출 범위 설정 후 이용권을 사용하세요.';
    }
    return '추가 모집·노출 범위 확장이 필요하면 패키지를 구매하세요.';
  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: AppColors.background,

      body: Stack(

        children: [

          if (_loading)

            const Center(child: CircularProgressIndicator())

          else if (_posts.isEmpty)

            EmptyStateCard(

              icon: Icons.article_outlined,

              title: '등록된 공고가 없습니다',

              message: '우측 하단 + 버튼으로\n새 공고를 등록해 보세요.',

              actionLabel: '공고 등록하기',

              onAction: _openCreate,

            )

          else

            ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
              children: [
                if (_wallet != null) ...[
                  _PushPolicyStatusBanner(wallet: _wallet!),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < _posts.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final post = _posts[i];
                      final availability = ExtraPushAvailability.resolve(
                        post: post,
                        wallet: _wallet,
                      );
                      return CorporateJobPostCard(
                        post: post,
                        extraPushAvailability: availability,
                        creditsDisplay: _wallet == null
                            ? null
                            : PushWalletCreditPolicy.jobPostCardCredits(
                                wallet: _wallet!,
                              ),
                        onView: () => _viewPost(post),
                        onEdit: () => _editPost(post),
                        onDelete: () => _deletePost(post),
                        onConfigureExposure: () => _configureExposure(post),
                        onRecruit: () => _recruit(post),
                        onOpenShop: _scrollToShopGrid,
                        onApplicantsTap: post.applicantCount > 0
                            ? () => widget.onViewApplicants?.call(post)
                            : null,
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
                    child: PushPackageQuickShopGrid(
                      message: _shopGridMessage(),
                      onPurchased: _load,
                    ),
                  ),
                ),
              ],
            ),

          Positioned.fill(

            child: CorporateJobPostSpeedDial(

              onCreate: _openCreate,

              onEdit: _openEditPicker,

            ),

          ),

        ],

      ),

    );

  }

}



class _PushPolicyStatusBanner extends StatelessWidget {

  const _PushPolicyStatusBanner({required this.wallet});



  final EmployerPushWallet wallet;



  @override

  Widget build(BuildContext context) {

    final credits = PushWalletCreditPolicy.jobPostCardCredits(wallet: wallet);

    final pkg = wallet.packageRecruitCredits;

    final freeHint = credits.accountFreePushHint;

    final freeUsed = !wallet.dailyFreePostingAvailable;



    return Container(

      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

      decoration: BoxDecoration(

        color: AppColors.primary.withValues(alpha: 0.06),

        borderRadius: BorderRadius.circular(12),

        border: Border.all(

          color: AppColors.primary.withValues(alpha: 0.18),

        ),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text(

            '공고 등록 무료',

            style: TextStyle(

              fontSize: 13,

              fontWeight: FontWeight.w800,

              color: AppColors.textPrimary,

            ),

          ),

          const SizedBox(height: 4),

          Text(

            [

              if (freeHint != null) freeHint!,

              if (freeUsed) '근무지 1km · 오늘 무료 푸시 소진',

              if (pkg > 0) '지역 푸시권 $pkg회',

              if (pkg <= 0 && freeUsed)

                '모집지역 푸시는 지역 푸시권 구매 필요',

            ].join(' · '),

            style: TextStyle(

              fontSize: 12,

              height: 1.45,

              fontWeight: FontWeight.w600,

              color: AppColors.textSecondary.withValues(alpha: 0.95),

            ),

          ),

        ],

      ),

    );

  }

}


