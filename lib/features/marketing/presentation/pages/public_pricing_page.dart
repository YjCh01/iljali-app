import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/presentation/widgets/auth_form_card.dart';
import 'package:map/features/auth/presentation/widgets/auth_primary_button.dart';
import 'package:map/features/auth/presentation/widgets/auth_scaffold.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// PG 심사·비로그인 방문용 공개 요금 안내
class PublicPricingPage extends StatelessWidget {
  const PublicPricingPage({super.key});

  static const _products = [
    _PricingRow(
      name: PushPackageCatalog.jobPinProductName,
      priceKrw: PushPackageCatalog.exposureUnitPriceKrw,
      description: PushPackageCatalog.jobPinDescription,
    ),
    _PricingRow(
      name: PushPackageCatalog.shuttlePinProductName,
      priceKrw: PushPackageCatalog.exposureUnitPriceKrw,
      description: PushPackageCatalog.shuttlePinDescription,
    ),
    _PricingRow(
      name: PushPackageCatalog.pushOnlyShopProductName,
      priceKrw: PushPackageCatalog.pushOnlyUnitPriceKrw,
      description: PushPackageCatalog.pushOnlyDescription,
    ),
    _PricingRow(
      name: PushPackageCatalog.comboProductName,
      priceKrw: PushPackageCatalog.exposureWithPushUnitPriceKrw,
      description: PushPackageCatalog.comboDescription,
    ),
  ];

  void _goCorporateLogin(BuildContext context) {
    Navigator.of(context).pushNamed(
      AppRoutes.login,
      arguments: MemberType.corporate,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthFormCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '유료 서비스 요금',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '기업회원이 채용 홍보·모집에 이용하는 디지털 상품입니다. '
                  '결제는 토스페이먼츠(PG)를 통해 진행됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 20),
                for (final product in _products) ...[
                  _ProductCard(product: product),
                  const SizedBox(height: 12),
                ],
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE4DEFF)),
                  ),
                  child: Text(
                    '10회 팩은 단품 대비 ${PushPackageCatalog.pack10DiscountPercent}% 할인 · '
                    '보유금 선충전(5만~50만원)도 기업회원 결제 메뉴에서 이용할 수 있습니다.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                AuthPrimaryButton(
                  label: '기업회원 로그인 후 결제하기',
                  onPressed: () => _goCorporateLogin(context),
                ),
                const SizedBox(height: 8),
                Text(
                  '가격은 부가세 포함 기준이며, 실제 결제 화면에서 최종 금액이 표시됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingRow {
  const _PricingRow({
    required this.name,
    required this.priceKrw,
    required this.description,
  });

  final String name;
  final int priceKrw;
  final String description;
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final _PricingRow product;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.searchBarBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.searchBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                PushPackageCatalog.krwSuffix(product.priceKrw),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.description,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
        ],
      ),
    );
  }
}
