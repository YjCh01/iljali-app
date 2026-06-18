import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/services/push_package_purchase_service.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_amount_breakdown.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';

Future<bool?> showPushTicketPurchaseSheet(
  BuildContext context, {
  int initialQuantity = 1,
  int? pushCredits,
  int? eligibleLocations,
}) {
  final suggestedQuantity = _suggestedPurchaseQuantity(
    pushCredits: pushCredits,
    eligibleLocations: eligibleLocations,
    fallback: initialQuantity,
  );
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _PushTicketPurchaseSheet(
      initialQuantity: suggestedQuantity,
      pushCredits: pushCredits,
      eligibleLocations: eligibleLocations,
    ),
  );
}

int _suggestedPurchaseQuantity({
  required int? pushCredits,
  required int? eligibleLocations,
  required int fallback,
}) {
  if (eligibleLocations == null || pushCredits == null) {
    return fallback.clamp(1, 99);
  }
  if (eligibleLocations <= pushCredits) return 1;
  return (eligibleLocations - pushCredits).clamp(1, 99);
}

class _PushTicketPurchaseSheet extends StatefulWidget {
  const _PushTicketPurchaseSheet({
    required this.initialQuantity,
    this.pushCredits,
    this.eligibleLocations,
  });

  final int initialQuantity;
  final int? pushCredits;
  final int? eligibleLocations;

  @override
  State<_PushTicketPurchaseSheet> createState() =>
      _PushTicketPurchaseSheetState();
}

class _PushTicketPurchaseSheetState extends State<_PushTicketPurchaseSheet> {
  final _purchaseService = PushPackagePurchaseService();

  late int _quantity;
  PaymentMethod _method = PaymentMethodCatalog.defaultMethod;
  bool _processing = false;
  bool _agreedToTerms = false;
  String? _errorMessage;

  int get _unitPriceKrw => PushPackageCatalog.pushOnlyUnitPriceKrw;

  int get _totalKrw => _quantity * _unitPriceKrw;

  @override
  void initState() {
    super.initState();
    _quantity = widget.initialQuantity;
  }

  void _changeQuantity(int delta) {
    setState(() {
      _quantity = (_quantity + delta).clamp(1, 99);
    });
  }

  Future<void> _checkout() async {
    if (_processing) return;

    if (!_agreedToTerms) {
      setState(() => _errorMessage = '결제 이용약관에 동의해 주세요.');
      return;
    }

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;

    final offer = PushPackageCatalog.findById(PushPackageCatalog.pushSingleId);
    if (offer == null) return;

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final result = await _purchaseService.purchase(
      context: context,
      profile: profile,
      offer: offer,
      method: _method,
      quantity: _quantity,
    );

    if (!mounted) return;
    setState(() => _processing = false);

    if (!result.success) {
      if (result.message != null) {
        showTransientSnackBar(context, result.message!);
      }
      return;
    }

    if (result.message != null) {
      showTransientSnackBar(context, result.message!);
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.92;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: bottomInset + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.searchBarBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PUSH 이용권 결제',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              if (widget.pushCredits != null && widget.eligibleLocations != null)
                _PushTicketPurchaseContextBanner(
                  pushCredits: widget.pushCredits!,
                  eligibleLocations: widget.eligibleLocations!,
                  selectedQuantity: _quantity,
                ),
              if (widget.pushCredits != null && widget.eligibleLocations != null)
                const SizedBox(height: 12),
              Text(
                '이용권은 미리 구매할 수 있습니다. '
                '① 알림핀/표시핀 추가 → ② 노출 결제 → ③ 이용권 결제 후 발송 순서이며, '
                '사용 시점에 노출 중인 위치에서만 1회씩 차감됩니다.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.95),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          PushTicketCatalog.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          PushTicketCatalog.unitDescription,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PackageQuantityStepper(
                    quantity: _quantity,
                    onDecrement: _processing ? null : () => _changeQuantity(-1),
                    onIncrement: _processing ? null : () => _changeQuantity(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.searchBarBorder),
                ),
                child: Row(
                  children: [
                    Text(
                      '단가 ${PushTicketCatalog.unitPriceLabel}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '합계 ${PushPackageCatalog.krwSuffix(_totalKrw)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              PaymentMethodSelectionSection(
                selectedMethod: _method,
                onMethodSelected:
                    _processing ? (_) {} : (m) => setState(() => _method = m),
                enabled: !_processing,
              ),
              const SizedBox(height: 12),
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: CheckboxListTile(
                  value: _agreedToTerms,
                  onChanged: _processing
                      ? null
                      : (value) => setState(() {
                            _agreedToTerms = value ?? false;
                            _errorMessage = null;
                          }),
                  activeColor: AppColors.primary,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 0,
                  ),
                  title: const Text(
                    '결제 진행 및 환불·취소 정책에 동의합니다.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '전자금융거래 이용약관 · 개인정보 제3자 제공',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              PaymentAmountBreakdown(
                lines: [
                  PaymentBreakdownLine(
                    label: 'PUSH 이용권 · $_quantity회',
                    amountKrw: _totalKrw,
                  ),
                ],
                totalKrw: _totalKrw,
                action: FilledButton(
                  onPressed: _processing ? null : _checkout,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _processing
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '결제하기',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PushTicketPurchaseContextBanner extends StatelessWidget {
  const _PushTicketPurchaseContextBanner({
    required this.pushCredits,
    required this.eligibleLocations,
    required this.selectedQuantity,
  });

  final int pushCredits;
  final int eligibleLocations;
  final int selectedQuantity;

  @override
  Widget build(BuildContext context) {
    final shortage =
        eligibleLocations > pushCredits ? eligibleLocations - pushCredits : 0;
    final afterPurchase = pushCredits + selectedQuantity;
    final coversAll =
        eligibleLocations > 0 && afterPurchase >= eligibleLocations;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: eligibleLocations > 0
            ? AppColors.primary.withValues(alpha: 0.08)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: eligibleLocations > 0
              ? AppColors.primary.withValues(alpha: 0.28)
              : Colors.orange.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PUSH 이용권 $pushCredits회 보유 · 발송 가능 위치 $eligibleLocations곳',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: eligibleLocations > 0
                  ? AppColors.primary.withValues(alpha: 0.95)
                  : Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 6),
          if (eligibleLocations == 0)
            Text(
              '아직 노출된 알림핀·정류장이 없습니다. 이용권은 미리 구매할 수 있으나, '
              '발송은 노출 결제 후에만 가능합니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            )
          else if (shortage > 0)
            Text(
              coversAll
                  ? '선택 수량 $selectedQuantity회 결제 시 총 $afterPurchase회 — '
                      '현재 노출 위치 $eligibleLocations곳 모두 발송 가능합니다.'
                  : '부족분 $shortage회 — 최소 $shortage회 구매 시 모든 노출 위치에서 발송할 수 있습니다. '
                      '(현재 선택 $selectedQuantity회 → 결제 후 $afterPurchase회)',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            )
          else
            Text(
              '보유 이용권으로 현재 노출 위치 $eligibleLocations곳 모두 발송할 수 있습니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
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
  const _StepperButton({required this.icon, this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      visualDensity: VisualDensity.compact,
    );
  }
}
