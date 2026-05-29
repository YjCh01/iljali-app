import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_home_plan_strip.dart';

/// 홈 탭 — 기본 vs 패키지 가로 스트립 (세로 배열)
class CorporateHomeFeatureHighlights extends StatelessWidget {
  const CorporateHomeFeatureHighlights({
    super.key,
    required this.onPushHiring,
    required this.onInstantMatching,
  });

  final VoidCallback onPushHiring;
  final VoidCallback onInstantMatching;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BasicPlanStrip(onTap: onPushHiring),
        const SizedBox(height: 10),
        _PackageBenefitStrip(onTap: onInstantMatching),
      ],
    );
  }
}

class _BasicPlanStrip extends StatelessWidget {
  const _BasicPlanStrip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return CorporateHomePlanStrip(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            Icons.article_outlined,
            size: 28,
            color: AppColors.textSecondary.withValues(alpha: 0.85),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                const Text(
                  '공고 등록 무료',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.searchBarBorder),
                  ),
                  child: Text(
                    PushPackageCatalog.defaultPlanLabel,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const ActivePlanInUseBadge(),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

class _PackageBenefitStrip extends StatelessWidget {
  const _PackageBenefitStrip({required this.onTap});

  final VoidCallback onTap;

  static const _lightPurple = Color(0xFFF3EEFF);
  static const _lightPurpleBorder = Color(0xFFD4C4FF);

  @override
  Widget build(BuildContext context) {
    return CorporateHomePlanStrip(
      onTap: onTap,
      backgroundColor: _lightPurple,
      borderColor: _lightPurpleBorder,
      shadow: true,
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome,
            size: 26,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '유료 지역 푸시권',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '5,000원/회 · 10/30/100회 번들 · 100회 팩만 황금핀(◆)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary.withValues(alpha: 0.88),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '구매 →',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
