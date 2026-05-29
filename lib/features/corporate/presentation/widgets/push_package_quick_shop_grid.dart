import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// 공고 관리 등 — 패키지 구매 바로가기 그리드
class PushPackageQuickShopGrid extends StatelessWidget {
  const PushPackageQuickShopGrid({
    super.key,
    this.title = '지역 푸시권 충전',
    this.message,
    this.compact = false,
    this.onPurchased,
  });

  final String title;
  final String? message;
  final bool compact;
  final VoidCallback? onPurchased;

  static const _offers = PushPackageCatalog.allOffers;

  Future<void> _openShop(BuildContext context, {String? offerId}) async {
    final purchased = await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushPackageShop,
      arguments: offerId,
    );
    if (purchased == true) onPurchased?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      message!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 10 : 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: compact ? 8 : 10,
            crossAxisSpacing: compact ? 8 : 10,
            childAspectRatio: compact ? 1.55 : 1.45,
          ),
          itemCount: _offers.length,
          itemBuilder: (context, index) {
            final offer = _offers[index];
            return _OfferTile(
              offer: offer,
              onTap: () => _openShop(context, offerId: offer.id),
            );
          },
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _openShop(context),
          child: const Text(
            '지역 푸시권 상세·결제',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({
    required this.offer,
    required this.onTap,
  });

  final PushPackageBundleOffer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSingle = offer.packageCount == 1;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSingle
                  ? AppColors.primary.withValues(alpha: 0.45)
                  : AppColors.searchBarBorder,
              width: isSingle ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isSingle ? '1회' : offer.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (offer.discountPercent > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8FBEA),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-${offer.discountPercent}%',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                offer.priceLabel,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isSingle ? '반경 1km · 1회' : '${offer.packageCount}회 · 반경 1km',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
