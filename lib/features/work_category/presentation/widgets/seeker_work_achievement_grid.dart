import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/work_category/domain/entities/seeker_work_achievement.dart';
import 'package:map/features/work_category/domain/entities/work_category_catalog.dart';
import 'package:map/features/work_category/presentation/widgets/work_achievement_badge_icon.dart';

/// 구직자 업무 업적 그리드 (게임 업적창 스타일)
class SeekerWorkAchievementGrid extends StatelessWidget {
  const SeekerWorkAchievementGrid({
    super.key,
    required this.summary,
    this.showLocked = true,
    this.iconSize = 48,
  });

  final SeekerWorkAchievementSummary summary;
  final bool showLocked;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final earned = summary.earnedEntries;
    final items = showLocked
        ? WorkCategoryCatalog.all
        : earned
            .map((e) => e.definition)
            .whereType()
            .toList();

    if (items.isEmpty && !showLocked) {
      return Text(
        '아직 달성한 업무 업적이 없습니다.',
        style: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary.withValues(alpha: 0.95),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 12,
      children: [
        for (final def in items)
          SizedBox(
            width: iconSize + 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                WorkAchievementBadgeIcon(
                  definition: def,
                  count: summary.countFor(def.id),
                  size: iconSize,
                  dimmed: summary.countFor(def.id) == 0,
                ),
                const SizedBox(height: 4),
                Text(
                  def.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: summary.countFor(def.id) > 0
                        ? AppColors.textPrimary
                        : AppColors.textSecondary.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
