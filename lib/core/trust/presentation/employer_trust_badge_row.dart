import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/trust/employer_trust_badge.dart';

/// 구직자 앱 — 고용주 평점·신뢰 배지 한 줄
class EmployerTrustBadgeRow extends StatelessWidget {
  const EmployerTrustBadgeRow({
    super.key,
    required this.summary,
    this.compact = false,
  });

  final EmployerTrustSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) return const SizedBox.shrink();

    final rating = summary.ratingSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (rating.reviewCount > 0) ...[
              Icon(
                Icons.star_rounded,
                size: compact ? 14 : 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                rating.displayStars,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '신뢰 ${summary.score}',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: rating.reviewCount > 0
                    ? AppColors.textSecondary
                    : AppColors.primary,
              ),
            ),
            if (summary.completedHires > 0) ...[
              const SizedBox(width: 8),
              Text(
                '채용완료 ${summary.completedHires}',
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ],
        ),
        if (summary.badges.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: summary.badges
                .map(
                  (badge) => Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 6 : 8,
                      vertical: compact ? 2 : 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${badge.emoji} ${badge.label}',
                      style: TextStyle(
                        fontSize: compact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        if (rating.topTags.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            rating.topTags.join(' · '),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
        ],
      ],
    );
  }
}
