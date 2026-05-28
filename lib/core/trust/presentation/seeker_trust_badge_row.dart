import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/trust/seeker_trust_badge.dart';

/// 구직자 신뢰 배지·점수 한 줄 표시
class SeekerTrustBadgeRow extends StatelessWidget {
  const SeekerTrustBadgeRow({
    super.key,
    required this.summary,
    this.compact = false,
  });

  final SeekerTrustSummary summary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (summary.badges.isEmpty && summary.checkInCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '신뢰 ${summary.score}',
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '출근 ${summary.checkInCount} · 노쇼 ${summary.noShowCount}',
              style: TextStyle(
                fontSize: compact ? 10 : 11,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
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
      ],
    );
  }
}
