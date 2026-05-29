import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// 모집지역 목록 하단 고정 「+」 행 — 설정 시트·노출 범위 설정 공통
class ExposureZoneAddRow extends StatelessWidget {
  const ExposureZoneAddRow({
    super.key,
    required this.remainingCredits,
    required this.rowHeight,
    required this.listRadius,
    this.onTap,
  });

  final int remainingCredits;
  final double rowHeight;
  final double listRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final canAdd = remainingCredits > 0 && onTap != null;
    final exhausted = remainingCredits <= 0;
    final label = ExposurePointLabels.addZoneButtonLabel(remainingCredits);
    final rowRadius = BorderRadius.vertical(
      bottom: Radius.circular(listRadius),
    );

    return Material(
      color: exhausted
          ? AppColors.background
          : AppColors.primaryLight.withValues(alpha: 0.1),
      borderRadius: rowRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: canAdd ? onTap : null,
        borderRadius: rowRadius,
        child: SizedBox(
          height: rowHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_rounded,
                size: 20,
                color: exhausted
                    ? AppColors.textSecondary.withValues(alpha: 0.55)
                    : AppColors.primary.withValues(alpha: 0.95),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: exhausted ? 13 : 12,
                  fontWeight: FontWeight.w800,
                  color: exhausted
                      ? AppColors.textSecondary.withValues(alpha: 0.65)
                      : AppColors.primary.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
