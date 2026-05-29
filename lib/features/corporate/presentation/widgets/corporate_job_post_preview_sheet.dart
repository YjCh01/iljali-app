import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 기업회원 — 공고 미리보기 (지원자 노출 화면 확인)
Future<void> showCorporateJobPostPreviewSheet(
  BuildContext context,
  CorporateJobPost post,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => CorporateJobPostPreviewSheet(post: post),
  );
}

class CorporateJobPostPreviewSheet extends StatelessWidget {
  const CorporateJobPostPreviewSheet({super.key, required this.post});

  final CorporateJobPost post;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '공고 미리보기',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                Text(
                  '지원자에게 이렇게 보입니다',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _PreviewRow(
                          icon: Icons.storefront_outlined,
                          text: post.branchName != null
                              ? '${post.branchName} · ${post.warehouseName}'
                              : post.warehouseName,
                        ),
                        _PreviewRow(
                          icon: Icons.payments_outlined,
                          text: post.dailyWage != null
                              ? '시급 ${post.hourlyWage} · 일급 ${post.dailyWage}'
                              : '시급 ${post.hourlyWage}',
                        ),
                        if (post.paymentScheduleDisplayLabel != null)
                          _PreviewRow(
                            icon: Icons.event_outlined,
                            text: '급여지급 ${post.paymentScheduleDisplayLabel}',
                          ),
                        _PreviewRow(
                          icon: Icons.schedule_outlined,
                          text: post.workSchedule,
                        ),
                        if (post.notificationSettings?.hasConfiguredBase ??
                            false)
                          for (final label
                              in post.notificationSettings!.exposurePointLabels)
                            _PreviewRow(
                              icon: Icons.notifications_active_outlined,
                              text: label,
                            ),
                        const SizedBox(height: 14),
                        Text(
                          post.fullDescriptionText,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.55,
                            color: AppColors.textPrimary.withValues(alpha: 0.95),
                          ),
                        ),
                      ],
                    ),
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

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
