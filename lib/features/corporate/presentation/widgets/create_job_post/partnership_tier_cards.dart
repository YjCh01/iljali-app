import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';

/// 기본 플랜 + PUSH·거점 패키지 안내 (레거시 티어 비교 UI 제거)
class PartnershipTierCards extends StatefulWidget {
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
  State<PartnershipTierCards> createState() => _PartnershipTierCardsState();
}

class _PartnershipTierCardsState extends State<PartnershipTierCards> {
  int _singleQuantity = 1;

  void _changeSingleQuantity(int delta) {
    setState(() {
      _singleQuantity = (_singleQuantity + delta).clamp(1, 99);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopTap = widget.onShopTap ??
        (widget.onUpgradeTap != null
            ? () => widget.onUpgradeTap!(PremiumPartnershipTier.basic)
            : null);
    final singleOffer = PushPackageCatalog.allOffers.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.comparisonOnly) ...[
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
              PremiumPartnershipPlans.pushStrategyNote,
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PackagePlanCard(
          title: '1회',
          subtitle: singleOffer.cardDetailLine,
          highlight: false,
          footer: _PackageQuantityStepper(
            quantity: _singleQuantity,
            onDecrement: () => _changeSingleQuantity(-1),
            onIncrement: () => _changeSingleQuantity(1),
          ),
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
              '일자리 알림핀 보기',
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
    this.footer,
  });

  final String title;
  final String subtitle;
  final bool highlight;
  final String? badge;
  final int? discountPercent;
  final Widget? footer;

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
            if (footer != null) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: footer),
            ],
          ],
        ),
      ),
    );
  }
}

class _PackageQuantityStepper extends StatelessWidget {
  const _PackageQuantityStepper({
    required this.quantity,
    required this.onDecrement,
    required this.onIncrement,
  });

  final int quantity;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            onPressed: quantity > 1 ? onDecrement : null,
          ),
          SizedBox(
            width: 28,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            onPressed: onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: onPressed == null
                ? AppColors.textSecondary.withValues(alpha: 0.35)
                : AppColors.textPrimary,
          ),
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
