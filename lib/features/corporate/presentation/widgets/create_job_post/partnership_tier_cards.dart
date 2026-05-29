import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';



/// 기본 플랜 + 푸시·거점 패키지 안내 (레거시 티어 비교 UI 제거)

class PartnershipTierCards extends StatelessWidget {

  const PartnershipTierCards({

    super.key,

    this.onShopTap,

    this.comparisonOnly = false,

    // Legacy — ignored; kept for call-site compatibility during migration

    this.activeTier,

    this.selectedTier,

    this.onTierSelected,

    this.onUpgradeTap,

  });



  final VoidCallback? onShopTap;

  final bool comparisonOnly;

  final PremiumPartnershipTier? activeTier;

  final PremiumPartnershipTier? selectedTier;

  final ValueChanged<PremiumPartnershipTier>? onTierSelected;

  final ValueChanged<PremiumPartnershipTier>? onUpgradeTap;



  @override

  Widget build(BuildContext context) {

    final plan = activeTier ?? PartnershipPlanDefaults.activePlan;

    final shopTap = onShopTap ??

        (onUpgradeTap != null

            ? () => onUpgradeTap!(PremiumPartnershipTier.basic)

            : null);



    return Column(

      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [

        Container(

          padding: const EdgeInsets.all(12),

          decoration: BoxDecoration(

            color: AppColors.primary.withValues(alpha: 0.08),

            borderRadius: BorderRadius.circular(12),

            border: Border.all(

              color: AppColors.primaryLight.withValues(alpha: 0.45),

            ),

          ),

          child: Text(

            comparisonOnly

                ? '현재 ${plan.label}이 적용됩니다. '

                    '추가 모집지역 푸시는 지역 푸시권으로 확장하세요.'

                : PremiumPartnershipPlans.pushStrategyNote,

            style: TextStyle(

              fontSize: 12,

              height: 1.45,

              fontWeight: FontWeight.w600,

              color: AppColors.textSecondary.withValues(alpha: 0.95),

            ),

          ),

        ),

        const SizedBox(height: 12),

        _PackagePlanCard(

          title: plan.label,

          subtitle: plan.summaryLine,

          highlight: true,

          badge: '이용 중',

        ),

        const SizedBox(height: 10),

        ...PushPackageCatalog.bundles.map(

          (bundle) => Padding(

            padding: const EdgeInsets.only(bottom: 10),

            child: _PackagePlanCard(

              title: bundle.label,

              subtitle: bundle.cardDetailLine,

              discountPercent: bundle.discountPercent,

              highlight: false,

            ),

          ),

        ),

        const SizedBox(height: 4),

        Text(

          PushPlanEnforcement.planLimitSummary(),

          style: TextStyle(

            fontSize: 11,

            height: 1.4,

            color: AppColors.textSecondary.withValues(alpha: 0.9),

          ),

        ),

        if (shopTap != null) ...[

          const SizedBox(height: 12),

          FilledButton(

            onPressed: shopTap,

            style: FilledButton.styleFrom(

              backgroundColor: AppColors.primary,

              foregroundColor: Colors.white,

              padding: const EdgeInsets.symmetric(vertical: 14),

            ),

            child: const Text(

              '지역 푸시권 보기',

              style: TextStyle(fontWeight: FontWeight.w700),

            ),

          ),

        ],

      ],

    );

  }

}



class _PackagePlanCard extends StatelessWidget {

  const _PackagePlanCard({

    required this.title,

    required this.subtitle,

    required this.highlight,

    this.badge,

    this.discountPercent,

  });



  final String title;

  final String subtitle;

  final bool highlight;

  final String? badge;

  final int? discountPercent;



  @override

  Widget build(BuildContext context) {

    return Material(

      color: highlight

          ? AppColors.primary.withValues(alpha: 0.06)

          : AppColors.surface,

      borderRadius: BorderRadius.circular(14),

      child: Ink(

        padding: const EdgeInsets.all(14),

        decoration: BoxDecoration(

          borderRadius: BorderRadius.circular(14),

          border: Border.all(

            color: highlight ? AppColors.primary : AppColors.searchBarBorder,

            width: highlight ? 1.5 : 1,

          ),

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              children: [

                Expanded(

                  child: Text(

                    title,

                    style: TextStyle(

                      fontWeight: FontWeight.w800,

                      fontSize: 16,

                      color: highlight

                          ? AppColors.primary

                          : AppColors.textPrimary,

                    ),

                  ),

                ),

                if (discountPercent != null && discountPercent! > 0)

                  _DiscountBadge(percent: discountPercent!)

                else if (badge != null)

                  Container(

                    padding:

                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                    decoration: BoxDecoration(

                      color: AppColors.primaryLight.withValues(alpha: 0.35),

                      borderRadius: BorderRadius.circular(8),

                    ),

                    child: Text(

                      badge!,

                      style: TextStyle(

                        fontSize: 10,

                        fontWeight: FontWeight.w800,

                        color: AppColors.primary.withValues(alpha: 0.95),

                      ),

                    ),

                  ),

              ],

            ),

            const SizedBox(height: 6),

            Text(

              subtitle,

              style: TextStyle(

                fontSize: 12,

                height: 1.35,

                color: AppColors.textSecondary.withValues(alpha: 0.95),

              ),

            ),

          ],

        ),

      ),

    );

  }

}



class _DiscountBadge extends StatelessWidget {

  const _DiscountBadge({required this.percent});



  final int percent;



  @override

  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),

      decoration: BoxDecoration(

        color: const Color(0xFFE8FBEA),

        borderRadius: BorderRadius.circular(999),

        border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6)),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(

            Icons.sell_outlined,

            size: 14,

            color: Colors.green.shade700,

          ),

          const SizedBox(width: 4),

          Text(

            '-$percent%',

            style: TextStyle(

              fontSize: 11,

              fontWeight: FontWeight.w800,

              color: Colors.green.shade800,

            ),

          ),

        ],

      ),

    );

  }

}


