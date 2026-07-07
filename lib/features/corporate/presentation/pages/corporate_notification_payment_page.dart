import 'package:flutter/material.dart';

import 'package:map/core/config/dev_experience_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';
import 'package:map/features/corporate/domain/services/job_post_payment_request_service.dart';
import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/services/saved_payment_method_service.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_amount_breakdown.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';
import 'package:map/features/corporate/presentation/widgets/payment/saved_card_checkout_section.dart';

/// 유료 서비스 PG 결제
class CorporateNotificationPaymentPage extends StatefulWidget {
  const CorporateNotificationPaymentPage({
    super.key,
    required this.bundle,
    this.paymentGateway,
    this.paymentRequestId,
    this.paymentKind,
  });

  final PushPaymentBundle bundle;
  final PaymentGatewayService? paymentGateway;
  final String? paymentRequestId;
  final JobPostPaymentRequestKind? paymentKind;



  @override

  State<CorporateNotificationPaymentPage> createState() =>

      _CorporateNotificationPaymentPageState();

}



class _CorporateNotificationPaymentPageState
    extends State<CorporateNotificationPaymentPage> {
  PaymentMethod _selectedMethod = PaymentMethodCatalog.defaultMethod;
  bool _agreedToTerms = false;
  bool _processing = false;
  String? _errorMessage;
  List<SavedPaymentMethod> _savedCards = [];
  String? _selectedCardId;
  bool _useOtherMethod = false;
  int _cashBalanceKrw = 0;

  JobPostPaymentRequestKind? get _effectiveKind =>
      widget.paymentKind ?? widget.bundle.paymentKind;

  PushPaymentBundle get _displayBundle {
    final kind = _effectiveKind;
    if (kind == null || kind == widget.bundle.paymentKind) {
      return widget.bundle;
    }
    return PushPaymentBundle(
      radiusTier: widget.bundle.radiusTier,
      pointTier: widget.bundle.pointTier,
      spotCount: widget.bundle.spotCount,
      isExtraPush: widget.bundle.isExtraPush,
      extraPushFeeKrw: widget.bundle.extraPushFeeKrw,
      paymentKind: kind,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCards();
    _loadCashBalance();
  }

  Future<void> _loadCashBalance() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return;
    final wallet = await PushWalletService().loadWallet(profile);
    if (!mounted) return;
    setState(() => _cashBalanceKrw = wallet.cashBalanceKrw);
  }

  Future<void> _loadSavedCards() async {
    final companyKey =
        AuthSession.instance.currentUser?.corporateProfile?.companyKey;
    if (companyKey == null || companyKey.isEmpty) return;
    final cards =
        await SavedPaymentMethodService().listForCompany(companyKey);
    if (!mounted) return;
    setState(() {
      _savedCards = cards;
      _selectedCardId = cards.isEmpty
          ? null
          : cards.firstWhere((c) => c.isDefault, orElse: () => cards.first).id;
      _useOtherMethod = cards.isEmpty;
    });
  }

  Future<void> _pay() async {
    if (!_agreedToTerms) {
      setState(() => _errorMessage = '결제 이용약관에 동의해 주세요.');
      return;
    }

    SavedPaymentMethod? savedCard;
    if (!_useOtherMethod && _selectedCardId != null) {
      savedCard = _savedCards.firstWhere(
        (c) => c.id == _selectedCardId,
        orElse: () => _savedCards.first,
      );
    }

    setState(() {
      _processing = true;
      _errorMessage = null;
    });

    final bundle = _displayBundle;
    final orderId = 'PUSH-${DateTime.now().millisecondsSinceEpoch}';
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    final request = PaymentRequest(
      orderId: orderId,
      productName: bundle.checkoutProductTitle,
      amountKrw: bundle.totalAmountKrw,
      method: savedCard != null ? PaymentMethod.card : _selectedMethod,
      radiusTier: bundle.radiusTier.isPaid ? bundle.radiusTier : null,
      buyerEmail: AuthSession.instance.currentUser?.email,
      buyerName: AuthSession.instance.currentUser?.name,
      companyKey: profile?.companyKey,
      savedPaymentMethodId: savedCard?.id,
      billingKey: savedCard?.billingKey,
    );
    final flow = PaymentFlowHelper(gateway: widget.paymentGateway);
    final result = await flow.pay(context, request);

    if (!mounted) return;

    if (result.success) {
      final txnId = result.transactionId ?? orderId;
      final requestId = widget.paymentRequestId;
      if (requestId != null && requestId.isNotEmpty) {
        await JobPostPaymentRequestService().markPaid(
          id: requestId,
          transactionId: txnId,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(
        PaymentCompletionResult(
          record: JobPostPaymentRecord(
            orderId: orderId,
            productName: bundle.checkoutProductTitle,
            amountKrw: bundle.totalAmountKrw,
            method: savedCard != null ? PaymentMethod.card : _selectedMethod,
            transactionId: txnId,
            paidAt: DateTime.now(),
            radiusTier: bundle.radiusTier.isPaid
                ? bundle.radiusTier
                : PushRadiusTier.standard1km,
          ),
        ),
      );
      return;
    }

    setState(() {
      _processing = false;
      _errorMessage = result.message ?? '결제에 실패했습니다. 다시 시도해 주세요.';
    });
  }



  List<PaymentBreakdownLine> _breakdownLines(PushPaymentBundle bundle, int price) {
    final vat = (price / 11).round();
    final supply = price - vat;

    if (bundle.isExtraPush) {
      return [
        PaymentBreakdownLine(
          label: bundle.checkoutBreakdownLabel,
          amountKrw: supply,
        ),
        PaymentBreakdownLine(label: '부가세 (10%)', amountKrw: vat),
      ];
    }

    return [
      PaymentBreakdownLine(label: '상품 금액', amountKrw: supply),
      PaymentBreakdownLine(label: '부가세 (10%)', amountKrw: vat),
    ];
  }



  @override

  Widget build(BuildContext context) {

    final bundle = _displayBundle;
    final price = bundle.totalAmountKrw;

    return Scaffold(

      backgroundColor: AppColors.background,

      appBar: AppBar(

        backgroundColor: AppColors.surface,

        foregroundColor: AppColors.textPrimary,

        elevation: 0,

        leading: const AppBackButton(),

        automaticallyImplyLeading: false,

        title: const Text('결제하기'),

      ),

      body: Column(

        children: [

          Expanded(

            child: ListView(

              children: [

                const SizedBox(height: 8),

                _OrderSummaryCard(bundle: bundle),
                if (_cashBalanceKrw > 0) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        '보유금 ${EmployerPushWallet(cashBalanceKrw: _cashBalanceKrw).cashBalanceLabel}원 — '
                        '결제 시 보유금 우선 차감, 부족분만 카드·간편결제로 청구됩니다.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary.withValues(alpha: 0.95),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SavedCardCheckoutSection(
                  cards: _savedCards,
                  selectedCardId: _selectedCardId,
                  onCardSelected: (id) => setState(() => _selectedCardId = id),
                  useOtherMethod: _useOtherMethod,
                  onUseOtherMethodChanged: (value) =>
                      setState(() => _useOtherMethod = value),
                  enabled: !_processing,
                ),
                if (_useOtherMethod || _savedCards.isEmpty) ...[
                  const SizedBox(height: 12),
                  PaymentMethodSelectionSection(
                    selectedMethod: _selectedMethod,
                    onMethodSelected: _processing
                        ? (_) {}
                        : (method) => setState(() => _selectedMethod = method),
                    enabled: !_processing,
                  ),
                ],

                const SizedBox(height: 16),

                Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 20),

                  child: Material(

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

                ),

                if (_errorMessage != null) ...[

                  const SizedBox(height: 12),

                  Padding(

                    padding: const EdgeInsets.symmetric(horizontal: 20),

                    child: Text(

                      _errorMessage!,

                      style: const TextStyle(

                        fontSize: 13,

                        color: Colors.redAccent,

                        fontWeight: FontWeight.w600,

                      ),

                    ),

                  ),

                ],

                const SizedBox(height: 12),

                if (DevExperienceFlags.enabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'QC 모드 — mock 결제입니다.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: AppColors.textSecondary.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 20),

              ],

            ),

          ),

          PaymentAmountBreakdown(
            lines: _breakdownLines(bundle, price),
            totalKrw: price,
            action: FilledButton(
              onPressed: _processing ? null : _pay,
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
                      height: 22,
                      width: 22,
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
    );
  }
}



class _OrderSummaryCard extends StatelessWidget {

  const _OrderSummaryCard({required this.bundle});



  final PushPaymentBundle bundle;



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(horizontal: 20),

      child: Container(

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(

          color: AppColors.surface,

          borderRadius: BorderRadius.circular(16),

          border: Border.all(color: AppColors.searchBarBorder),

        ),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text(

              '주문 상품',

              style: TextStyle(

                fontSize: 13,

                fontWeight: FontWeight.w600,

                color: AppColors.textSecondary,

              ),

            ),

            const SizedBox(height: 10),

            Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Container(

                  width: 44,

                  height: 44,

                  decoration: BoxDecoration(

                    color: AppColors.primaryLight.withValues(alpha: 0.25),

                    borderRadius: BorderRadius.circular(12),

                  ),

                  child: Icon(
                    _orderIcon(bundle.paymentKind),
                    color: AppColors.primary,
                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(
                        bundle.checkoutProductTitle,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bundle.checkoutProductDetail,

                        style: TextStyle(

                          fontSize: 13,

                          height: 1.4,

                          color: AppColors.textSecondary.withValues(alpha: 0.95),

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }



  static IconData _orderIcon(JobPostPaymentRequestKind? kind) =>
      switch (kind) {
        JobPostPaymentRequestKind.shuttleStopExposure =>
          Icons.directions_bus_rounded,
        JobPostPaymentRequestKind.jobPinExposure => Icons.place_rounded,
        JobPostPaymentRequestKind.pushTicket => Icons.campaign_rounded,
        JobPostPaymentRequestKind.packagePurchase => Icons.inventory_2_outlined,
        JobPostPaymentRequestKind.extraPush => Icons.campaign_rounded,
        null => Icons.place_rounded,
      };
}


