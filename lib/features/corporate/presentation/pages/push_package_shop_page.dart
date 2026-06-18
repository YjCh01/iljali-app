import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/core/widgets/push_wallet_bonus_feedback.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_package_purchase_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/presentation/pages/corporate_tax_documents_page.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_amount_breakdown.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';

/// PUSH·거점 패키지 상점 (단품 + 번들)
class PushPackageShopPage extends StatefulWidget {
  const PushPackageShopPage({super.key, this.initialOfferId});

  final String? initialOfferId;

  @override
  State<PushPackageShopPage> createState() => _PushPackageShopPageState();
}

class _PushPackageShopPageState extends State<PushPackageShopPage> {
  final _purchaseService = PushPackagePurchaseService();
  final _walletService = PushWalletService();

  late PushPackageBundleOffer _selected;
  PaymentMethod _method = PaymentMethodCatalog.defaultMethod;
  int _purchaseQuantity = 1;
  bool _processing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selected = PushPackageCatalog.findById(widget.initialOfferId ?? '') ??
        PushPackageCatalog.jobPinOffers.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      clearSnackBarQueue(context);
    });
    _loadWallet();
  }

  Future<void> _loadWallet({bool showBonusSnackBar = true}) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final outcome = await _walletService.loadWalletDetailed(profile);
    if (!mounted) return;
    if (showBonusSnackBar) {
      showPushWalletBonusSnackBar(context, outcome);
    }
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
      await _loadWallet(showBonusSnackBar: false);
      if (!mounted) return;
      clearSnackBarQueue(context);
      showTransientSnackBar(
        context,
        result.message ??
            '${_selected.productName} $_checkoutQuantity회가 지갑에 충전되었습니다.',
        action: SnackBarAction(
          label: '증빙',
          onPressed: () => openCorporateTaxDocuments(context),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    setState(() => _error = result.message);
  }

  bool get _supportsQuantityStepper => _selected.supportsQuantitySelector;

  int get _checkoutQuantity =>
      _supportsQuantityStepper ? _purchaseQuantity : 1;

  int get _checkoutTotalKrw => _selected.priceKrw * _checkoutQuantity;

  String get _checkoutProductLabel => _checkoutQuantity > 1
      ? '${_selected.productName} ×$_checkoutQuantity'
      : _selected.productName;

  void _changePurchaseQuantity(int delta) {
    setState(() {
      _purchaseQuantity = (_purchaseQuantity + delta).clamp(1, 99);
    });
  }

  void _selectOffer(PushPackageBundleOffer offer) {
    setState(() {
      _selected = offer;
      _purchaseQuantity = 1;
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
        title: const Text('이용권 상점'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '이용권 상점',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '결제 후 이용권이 지갑에 충전됩니다. '
                  '노출 활성화·PUSH 발송은 공고목록에서 진행하세요.\n'
                  '근무지 ${PushPackageCatalog.pushRadiusLabel}는 공고 등록 시 기본 포함 · '
                  '노출 종료 ${PushPackageCatalog.exposureEndsLabel}.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 20),
                for (final section in PushPackageCatalog.shopSections) ...[
                  _ShopSectionHeader(title: section.title),
                  const SizedBox(height: 10),
                  ...PushPackageCatalog.resolveShopSectionOffers(section).map(
                    (offer) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _OfferCard(
                        offer: offer,
                        selected: offer.id == _selected.id,
                        processing: _processing,
                        purchaseQuantity: _purchaseQuantity,
                        onTap: () => _selectOffer(offer),
                        onDecrement: () => _changePurchaseQuantity(-1),
                        onIncrement: () => _changePurchaseQuantity(1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 4),
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
            action: FilledButton(
              onPressed: _processing ? null : _purchase,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _processing
                    ? '결제 중...'
                    : '${PushPackageCatalog.krwSuffix(_checkoutTotalKrw)} · '
                        '${_selected.productName} 구매',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShopSectionHeader extends StatelessWidget {
  const _ShopSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.selected,
    required this.processing,
    required this.purchaseQuantity,
    required this.onTap,
    required this.onDecrement,
    required this.onIncrement,
  });

  final PushPackageBundleOffer offer;
  final bool selected;
  final bool processing;
  final int purchaseQuantity;
  final VoidCallback onTap;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  @override
  Widget build(BuildContext context) {
    final displayTitle =
        offer.packageCount == 1 ? offer.productName : offer.label;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: processing ? null : onTap,
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
                          displayTitle,
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
                  if (offer.packageCount == 1 &&
                      offer.marketingLine.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      offer.marketingLine,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color:
                            AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    offer.priceLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (selected) const SizedBox(height: 36),
                  if (offer.extraBenefitLines.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ...offer.extraBenefitLines.map(
                      (line) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          line,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color:
                                AppColors.textPrimary.withValues(alpha: 0.9),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (offer.supportsQuantitySelector && selected)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: _PackageQuantityStepper(
                    quantity: purchaseQuantity,
                    onDecrement: processing ? null : onDecrement,
                    onIncrement: processing ? null : onIncrement,
                  ),
                ),
            ],
          ),
        ),
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
