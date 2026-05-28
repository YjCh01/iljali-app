import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';

/// 홈 플랜·패키지 가로 스트립 공통 크기
abstract final class CorporateHomePlanStripMetrics {
  static const height = 96.0;
  static const radius = 16.0;
  static const horizontalPadding = 16.0;
}

class CorporateHomePlanStrip extends StatelessWidget {
  const CorporateHomePlanStrip({
    super.key,
    required this.child,
    this.onTap,
    this.backgroundColor = AppColors.surface,
    this.borderColor = AppColors.searchBarBorder,
    this.shadow = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(CorporateHomePlanStripMetrics.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CorporateHomePlanStripMetrics.radius),
        child: Ink(
          height: CorporateHomePlanStripMetrics.height,
          padding: const EdgeInsets.symmetric(
            horizontal: CorporateHomePlanStripMetrics.horizontalPadding,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius:
                BorderRadius.circular(CorporateHomePlanStripMetrics.radius),
            border: Border.all(color: borderColor),
            boxShadow: shadow
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 형광 「이용중」 뱃지
class ActivePlanInUseBadge extends StatelessWidget {
  const ActivePlanInUseBadge({super.key, this.label = '이용중'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.activeBasicBadgeBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.activeBasicBadgeText.withValues(alpha: 0.2),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: AppColors.activeBasicBadgeText,
        ),
      ),
    );
  }
}
