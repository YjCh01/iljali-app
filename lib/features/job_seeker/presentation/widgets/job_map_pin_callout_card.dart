import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_display_labels.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 지도 핀 탭 시 — 압축 공고 카드
class JobMapPinCalloutCard extends StatelessWidget {
  const JobMapPinCalloutCard({
    super.key,
    required this.pin,
    required this.onClose,
    required this.onViewDetail,
    this.employerPreview = false,
    this.compact = false,
  });

  static const maxCompactWidth = 380.0;

  final JobMapPin pin;
  final VoidCallback onClose;
  final VoidCallback onViewDetail;
  final bool employerPreview;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final post = pin.post;
    final snippet = post.summary.trim().isNotEmpty
        ? post.summary.trim()
        : post.effectiveDescriptionBody.calloutSnippet;

    final titleSize = compact ? 15.0 : 18.0;
    final outerMargin = compact
        ? const EdgeInsets.symmetric(horizontal: 16)
        : const EdgeInsets.fromLTRB(12, 0, 12, 10);
    final radius = compact ? 14.0 : 16.0;

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: outerMargin,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: compact ? 0.1 : 0.14),
              blurRadius: compact ? 12 : 18,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 16, compact ? 10 : 14, 4, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                post.title,
                                maxLines: compact ? 1 : 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                ),
                              ),
                            ),
                            if (employerPreview)
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  '내 공고',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 4),
                          Text(
                            pin.companyName,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: Icon(Icons.close_rounded, size: compact ? 20 : 22),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(compact ? 12 : 16, compact ? 6 : 10, compact ? 12 : 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetaLine(
                          icon: Icons.place_outlined,
                          text: CorporateJobPostDisplayValues.siteLocation(post),
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 2 : 4),
                        _MetaLine(
                          icon: Icons.payments_outlined,
                          text: CorporateJobPostDisplayValues.salary(post),
                          compact: compact,
                        ),
                        if (!compact && snippet.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            snippet,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(width: 10),
                    _TierBadge(tier: pin.displayTier.name, post: post),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 12 : 16,
                compact ? 8 : 12,
                compact ? 12 : 16,
                compact ? 10 : 14,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: onViewDetail,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      '공고 상세보기',
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const Text(' · ', style: TextStyle(color: AppColors.textSecondary)),
                  Flexible(
                    child: Text(
                      employerPreview ? '구직자 화면 미리보기' : post.status.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({
    required this.icon,
    required this.text,
    this.compact = false,
  });

  final IconData icon;
  final String text;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: compact ? 14 : 15, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 11 : 12, height: 1.35),
          ),
        ),
      ],
    );
  }
}

class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier, required this.post});

  final String tier;
  final CorporateJobPost post;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.35),
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.work_outline_rounded,
            size: 22,
            color: AppColors.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 2),
          Text(
            post.hourlyWage.replaceAll('원', '').trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
