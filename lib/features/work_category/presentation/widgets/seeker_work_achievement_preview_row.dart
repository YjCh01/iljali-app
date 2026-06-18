import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/work_category/domain/entities/seeker_work_achievement.dart';
import 'package:map/features/work_category/presentation/widgets/work_achievement_badge_icon.dart';

/// 더보기 탭 — 달성 업적 미리보기 (상위 6개)
class SeekerWorkAchievementPreviewRow extends StatelessWidget {
  const SeekerWorkAchievementPreviewRow({
    super.key,
    required this.summary,
    this.onTapViewAll,
  });

  final SeekerWorkAchievementSummary summary;
  final VoidCallback? onTapViewAll;

  @override
  Widget build(BuildContext context) {
    final earned = summary.earnedEntries.take(6).toList();
    if (earned.isEmpty) {
      return Text(
        '근무 완료 시 물류·청소·행사 등 업적이 쌓입니다.',
        style: TextStyle(
          fontSize: 12,
          height: 1.4,
          color: AppColors.textSecondary.withValues(alpha: 0.9),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '현장 ${summary.totalCompletions}회 완료',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            const Spacer(),
            if (onTapViewAll != null)
              TextButton(
                onPressed: onTapViewAll,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('전체 보기'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in earned)
              if (entry.definition != null)
                WorkAchievementBadgeIcon(
                  definition: entry.definition!,
                  count: entry.count,
                  size: 40,
                ),
          ],
        ),
      ],
    );
  }
}
