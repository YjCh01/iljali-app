import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/work_category/domain/entities/work_category_definition.dart';

/// 업무 업적 뱃지 — 아이콘 + 누적 횟수, 터치/호버 시 이름
class WorkAchievementBadgeIcon extends StatelessWidget {
  const WorkAchievementBadgeIcon({
    super.key,
    required this.definition,
    required this.count,
    this.size = 44,
    this.dimmed = false,
    this.onTap,
  });

  final WorkCategoryDefinition definition;
  final int count;
  final double size;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final earned = count > 0;
    final iconColor = earned && !dimmed
        ? AppColors.primary
        : AppColors.textSecondary.withValues(alpha: 0.45);
    final bg = earned && !dimmed
        ? AppColors.primaryLight.withValues(alpha: 0.35)
        : Colors.grey.shade100;

    final badge = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: earned
                  ? AppColors.primary.withValues(alpha: 0.35)
                  : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(definition.icon, size: size * 0.48, color: iconColor),
        ),
        if (earned)
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
            ),
          ),
      ],
    );

    void showLabel() {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger != null) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('${definition.label}${earned ? ' · $count회' : ''}'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          ),
        );
      }
    }

    return Tooltip(
      message: '${definition.label}${earned ? ' ($count)' : ''}',
      preferBelow: kIsWeb,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap ?? showLabel,
          child: badge,
        ),
      ),
    );
  }
}
