import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_display_labels.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_description_body_view.dart';

/// 공고 미리보기 본문 — 모달·지도 하단 패널 공용
class CorporateJobPostPreviewPanel extends StatelessWidget {
  const CorporateJobPostPreviewPanel({
    super.key,
    required this.post,
    this.onClose,
    this.showHeader = true,
    this.scrollable = true,
  });

  final CorporateJobPost post;
  final VoidCallback? onClose;
  final bool showHeader;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = _PreviewContent(post: post);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
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
              if (onClose != null)
                IconButton(
                  onPressed: onClose,
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
        ],
        if (scrollable)
          Flexible(child: SingleChildScrollView(child: content))
        else
          content,
      ],
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.post});

  final CorporateJobPost post;

  @override
  Widget build(BuildContext context) {
    return Column(
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
        CorporateJobPostLabeledInfoRow(
          icon: Icons.storefront_outlined,
          label: CorporateJobPostDisplayLabels.siteLocation,
          value: CorporateJobPostDisplayValues.siteLocation(post),
          iconSize: 18,
          spacing: 8,
          bottomPadding: 8,
        ),
        CorporateJobPostLabeledInfoRow(
          icon: Icons.payments_outlined,
          label: CorporateJobPostDisplayLabels.salary,
          value: CorporateJobPostDisplayValues.salary(post),
          iconSize: 18,
          spacing: 8,
          bottomPadding: 8,
        ),
        if (CorporateJobPostDisplayValues.paymentSchedule(post) != null)
          CorporateJobPostLabeledInfoRow(
            icon: Icons.event_outlined,
            label: CorporateJobPostDisplayLabels.paymentSchedule,
            value: CorporateJobPostDisplayValues.paymentSchedule(post)!,
            iconSize: 18,
            spacing: 8,
            bottomPadding: 8,
          ),
        CorporateJobPostLabeledInfoRow(
          icon: Icons.schedule_outlined,
          label: CorporateJobPostDisplayLabels.workSchedule,
          value: CorporateJobPostDisplayValues.workSchedule(post.workSchedule),
          iconSize: 18,
          spacing: 8,
          bottomPadding: 8,
        ),
        if (post.notificationSettings?.hasConfiguredBase ?? false)
          for (final label in post.notificationSettings!.exposurePointLabels)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.primaryLight.withValues(alpha: 0.35),
            ),
          ),
          child: JobPostDescriptionBodyView(
            body: post.effectiveDescriptionBody,
          ),
        ),
      ],
    );
  }
}
