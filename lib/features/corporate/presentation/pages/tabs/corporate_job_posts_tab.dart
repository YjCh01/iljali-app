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

import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_job_post_card.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_job_post_speed_dial.dart';

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



  List<CorporateJobPost> _posts = [];

  int? _availablePushCredits;

  bool _loading = true;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    setState(() => _loading = true);

    final posts = await _getJobPosts();

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    int? credits;
    if (profile != null) {
      final wallet = await PushWalletService().loadWallet(profile);
      credits = wallet.availablePushCredits;
    }

    if (!mounted) return;

    setState(() {

      _posts = posts;

      _availablePushCredits = credits;

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



  Future<void> _sendExtraPush(CorporateJobPost post) async {

    final settings = post.notificationSettings;

    if (settings?.hasConfiguredBase != true) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('공고 노출 범위가 설정되지 않았습니다. 공고 수정에서 설정해 주세요.'),

        ),

      );

      return;

    }



    final radiusTier = settings!.primaryBase?.radiusTier;

    if (radiusTier == null || radiusTier == PushRadiusTier.radius0km) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('노출 반경이 0km인 공고는 지원자 모집하기를 사용할 수 없습니다.')),

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

    final credits = _availablePushCredits ?? 0;
    final confirmed = await showExtraPushConfirmSheet(
      context,
      post: post,
      availablePushCredits: credits,
    );
    if (!mounted || confirmed == null) return;

    if (confirmed.updatedBasePoints != null) {
      final updatedSettings = settings.copyWith(
        basePoints: confirmed.updatedBasePoints,
      );
      await _dataSource.updateJobPost(
        post.copyWith(notificationSettings: updatedSettings),
      );
    }

    final prepared = await PushDispatchService().prepare(
      context: context,
      profile: profile,
    );
    if (!mounted) return;
    if (prepared == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('지원자 모집하기 결제가 취소되었습니다.')),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushDispatch,
      arguments: PushDispatchArgs(
        radiusTier: prepared.radiusTier,
        recruitmentSlotCount: 1,
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
      SnackBar(content: Text('지원자 모집하기가 전송되었습니다.$feeLabel')),
    );

    await _load();
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

            ListView.separated(

              padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),

              itemCount: _posts.length,

              separatorBuilder: (_, __) => const SizedBox(height: 12),

              itemBuilder: (context, index) {

                final post = _posts[index];

                return CorporateJobPostCard(

                  post: post,

                  availablePushCredits: _availablePushCredits,

                  onEdit: () => _editPost(post),

                  onDelete: () => _deletePost(post),

                  onExtraPush: () => _sendExtraPush(post),

                  onApplicantsTap: post.applicantCount > 0
                      ? () => widget.onViewApplicants?.call(post)
                      : null,

                );

              },

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


