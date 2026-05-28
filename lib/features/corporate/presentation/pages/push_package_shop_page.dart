import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_package_purchase_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/presentation/widgets/map_pin_tier_preview.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_amount_breakdown.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';

/// 푸시·거점 패키지 상점 (단품 + 번들)
class PushPackageShopPage extends StatefulWidget {
  const PushPackageShopPage({super.key});

  @override
  State<PushPackageShopPage> createState() => _PushPackageShopPageState();
}

class _PushPackageShopPageState extends State<PushPackageShopPage> {
  final _purchaseService = PushPackagePurchaseService();
  final _walletService = PushWalletService();

  PushPackageBundleOffer _selected = PushPackageCatalog.allOffers.first;
  PaymentMethod _method = PaymentMethodCatalog.defaultMethod;
  int _singleQuantity = 1;
  bool _processing = false;
  String? _error;
  String? _walletSummary;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await _walletService.loadWallet(profile);
    if (!mounted) return;
    setState(() => _walletSummary = PushWalletService.walletSummary(wallet));
  }

  Future<void> _purchase() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      setState(() => _error = '기업 프로필을 불러올 수 없습니다.');
      return;
    }

    setState(() {
      _processing = true;
      _error = null;
    });

    final result = await _purchaseService.purchase(
      context: context,
      profile: profile,
      offer: _selected,
      method: _method,
      quantity: _checkoutQuantity,
    );

    if (!mounted) return;
    setState(() => _processing = false);

    if (result.success) {
      await _loadWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? '충전 완료'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _error = result.message);
  }

  bool get _isSingleSelected =>
      _selected.id == PushPackageCatalog.singlePackageId;

  int get _checkoutQuantity => _isSingleSelected ? _singleQuantity : 1;

  int get _checkoutTotalKrw => _isSingleSelected
      ? PushPackageCatalog.singlePackagePriceKrw * _singleQuantity
      : _selected.priceKrw;

  String get _checkoutProductLabel => _checkoutQuantity > 1
      ? '${_selected.productName} ×$_checkoutQuantity'
      : _selected.productName;

  void _changeSingleQuantity(int delta) {
    setState(() {
      _singleQuantity = (_singleQuantity + delta).clamp(1, 99);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('공고 노출·모집 패키지'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '공고 노출·모집 패키지',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '패키지 1개 = 공고 노출 범위 1곳 + 지원자 모집하기 1회 (1km). '
                  '기본 플랜은 ${PushPackageCatalog.pushRadiusLabel} · '
                  '하루 ${PushPackageCatalog.dailyFreePush}회입니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                if (_walletSummary != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '현재 · $_walletSummary',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.searchBarBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '지도 핀 노출 등급',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '공고는 채용 완료까지 지도에 핀으로 노출됩니다. '
                        '100회 팩 구매 시 모든 공고가 노란 핀(◆)으로 표시됩니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const MapPinTierPreviewRow(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...PushPackageCatalog.allOffers.map((offer) {
                  final selected = offer.id == _selected.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _processing
                            ? null
                            : () => setState(() => _selected = offer),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.grey.withValues(alpha: 0.25),
                              width: selected ? 2 : 1,
                            ),
                            color: selected
                                ? AppColors.primaryLight.withValues(alpha: 0.12)
                                : AppColors.surface,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      offer.label,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  if (offer.discountPercent > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8FBEA),
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFF34D399)
                                              .withValues(alpha: 0.6),
                                        ),
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
                                            '-${offer.discountPercent}%',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.green.shade800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (selected) ...[
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                offer.packageCount == 1
                                    ? offer.marketingLine
                                    : offer.cardDetailLine,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary
                                      .withValues(alpha: 0.95),
                                ),
                              ),
                              if (offer.packageCount == 1) ...[
                                const SizedBox(height: 8),
                                Text(
                                  offer.priceLabel,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (selected) const SizedBox(height: 36),
                              ],
                              if (offer.extraBenefitLines.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ...offer.extraBenefitLines.map(
                                  (line) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome,
                                          size: 14,
                                          color: const Color(0xFFFFB800),
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            line,
                                            style: TextStyle(
                                              fontSize: 12,
                                              height: 1.35,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textPrimary
                                                  .withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                              ),
                              if (offer.packageCount == 1 && selected)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: () {},
                                    child: _PackageQuantityStepper(
                                    quantity: _singleQuantity,
                                    onDecrement: _processing
                                        ? null
                                        : () => _changeSingleQuantity(-1),
                                    onIncrement: _processing
                                        ? null
                                        : () => _changeSingleQuantity(1),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 12),
                PaymentMethodSelectionSection(
                  selectedMethod: _method,
                  onMethodSelected:
                      _processing ? (_) {} : (m) => setState(() => _method = m),
                  enabled: !_processing,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
              ],
            ),
          ),
          PaymentAmountBreakdown(
            lines: [
              PaymentBreakdownLine(
                label: _checkoutProductLabel,
                amountKrw: _checkoutTotalKrw,
              ),
            ],
            totalKrw: _checkoutTotalKrw,
            totalLabel: '총 결제금액',
          ),
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: SafeArea(
              top: false,
              child: FilledButton(
                onPressed: _processing ? null : _purchase,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(
                  _processing
                      ? '결제 중...'
                      : '${PushPackageCatalog.krwSuffix(_checkoutTotalKrw)} · ${_selected.label} 구매',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageQuantityStepper extends StatelessWidget {
  const _PackageQuantityStepper({
    required this.quantity,
    this.onDecrement,
    this.onIncrement,
  });

  final int quantity;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

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
