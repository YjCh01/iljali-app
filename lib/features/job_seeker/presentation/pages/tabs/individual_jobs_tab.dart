import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/empty_state_card.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_job_posts_usecase.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_job_post_card.dart';
import 'package:map/features/job_seeker/domain/utils/job_map_pin_factory.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_post_detail_sheet.dart';

/// 구직자 2번 탭 — 진행 중 공고 목록 (↔ 기업 공고 관리)
class IndividualJobsTab extends StatefulWidget {
  const IndividualJobsTab({
    super.key,
    required this.reloadToken,
    this.onApplied,
    this.onOpenMapTab,
  });

  final int reloadToken;
  final VoidCallback? onApplied;
  final VoidCallback? onOpenMapTab;

  @override
  State<IndividualJobsTab> createState() => _IndividualJobsTabState();
}

class _IndividualJobsTabState extends State<IndividualJobsTab> {
  final _getPosts = const GetCorporateJobPostsUseCase(
    CorporateJobPostLocalDataSourceImpl(),
  );

  List<CorporateJobPost> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant IndividualJobsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadToken != widget.reloadToken) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final posts = await _getPosts();
    if (!mounted) return;
    setState(() {
      _posts = posts
          .where(
            (post) =>
                post.status == CorporateJobPostStatus.recruiting ||
                post.status == CorporateJobPostStatus.closingSoon,
          )
          .toList();
      _loading = false;
    });
  }

  void _openDetail(CorporateJobPost post) {
    final pin = jobMapPinFromPost(post);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => JobPostDetailSheet(
        pin: pin,
        onClose: () => Navigator.of(context).pop(),
        onApply: () async {
          final applied = await showJobApplyDialog(
            context,
            pin,
            onApplied: widget.onApplied,
          );
          if (applied && context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              '진행 중인 공고',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '탭하면 상세 보기 · 지원할 수 있습니다.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 14),
            if (_posts.isEmpty)
              SizedBox(
                height: 320,
                child: EmptyStateCard(
                  icon: Icons.work_off_outlined,
                  title: '모집 중인 공고가 없습니다',
                  message: '새 공고가 등록되면 지도와 목록에 표시됩니다.\n아래로 당겨 새로고침해 보세요.',
                  actionLabel: '지도에서 찾기',
                  onAction: widget.onOpenMapTab,
                ),
              )
            else
              ..._posts.map(
                (post) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SeekerJobPostCard(
                    post: post,
                    onTap: () => _openDetail(post),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
