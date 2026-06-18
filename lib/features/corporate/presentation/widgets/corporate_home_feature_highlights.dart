import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_plan_strip.dart';

/// 홈 탭 — 공고 등록 (무료 강조)
class CorporateHomeFeatureHighlights extends StatelessWidget {
  const CorporateHomeFeatureHighlights({
    super.key,
    required this.onPushHiring,
  });

  final VoidCallback onPushHiring;

  @override
  Widget build(BuildContext context) {
    return CorporateHomePlanStrip(
      onTap: onPushHiring,
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              '공고 등록 무료',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '등록 →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
