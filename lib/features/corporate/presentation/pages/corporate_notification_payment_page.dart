import 'package:flutter/material.dart';

import 'package:map/core/constants/app_colors.dart';

import 'package:map/core/widgets/app_back_button.dart';

import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';

import 'package:map/features/corporate/domain/entities/payment_method.dart';

import 'package:map/features/corporate/domain/entities/payment_method_option.dart';

import 'package:map/features/corporate/domain/entities/payment_request.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';

import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';

import 'package:map/features/corporate/presentation/widgets/payment/payment_amount_breakdown.dart';

import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';



/// 푸시 반경·지정포인트 — PG 결제 (MVP: mock, 추후 실 PG API 연동)

class CorporateNotificationPaymentPage extends StatefulWidget {

  const CorporateNotificationPaymentPage({

    super.key,

    required this.bundle,

    this.paymentGateway,

  });



  final PushPaymentBundle bundle;

  final PaymentGatewayService? paymentGateway;



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



  Future<void> _pay() async {

    if (!_agreedToTerms) {

      setState(() => _errorMessage = '결제 이용약관에 동의해 주세요.');

      return;

    }



    setState(() {

      _processing = true;

      _errorMessage = null;

    });



    final bundle = widget.bundle;

    final orderId = 'PUSH-${DateTime.now().millisecondsSinceEpoch}';

    final request = PaymentRequest(

      orderId: orderId,

      productName: '푸시 알림 · ${bundle.productSummary}',

      amountKrw: bundle.totalAmountKrw,

      method: _selectedMethod,

      radiusTier: bundle.radiusTier.isPaid ? bundle.radiusTier : null,

    );

    final flow = PaymentFlowHelper(gateway: widget.paymentGateway);

    final result = await flow.pay(context, request);



    if (!mounted) return;



    if (result.success) {

      Navigator.of(context).pop(

        PaymentCompletionResult(

          record: JobPostPaymentRecord(

            orderId: orderId,

            productName: '푸시 알림 · ${bundle.productSummary}',

            amountKrw: bundle.totalAmountKrw,

            method: _selectedMethod,

            transactionId: result.transactionId ?? 'UNKNOWN',

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

        PaymentBreakdownLine(label: '지원자 모집하기 (add-on)', amountKrw: supply),

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

    final bundle = widget.bundle;

    final price = bundle.totalAmountKrw;

    final formatted = formatKrw(price);

    final selectedLabel = PaymentMethodCatalog.byMethod(_selectedMethod).label;



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

                const SizedBox(height: 12),

                PaymentMethodSelectionSection(

                  selectedMethod: _selectedMethod,

                  onMethodSelected: _processing

                      ? (_) {}

                      : (method) => setState(() => _selectedMethod = method),

                  enabled: !_processing,

                ),

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

                Padding(

                  padding: const EdgeInsets.symmetric(horizontal: 20),

                  child: Text(

                    '현재는 테스트용 mock 결제입니다. 실제 PG 연동 시 가맹점 키·API Secret·웹훅 URL이 서버에 필요합니다.',

                    style: TextStyle(

                      fontSize: 11,

                      height: 1.45,

                      color: AppColors.textSecondary.withValues(alpha: 0.85),

                    ),

                  ),

                ),

                const SizedBox(height: 20),

              ],

            ),

          ),

          PaymentAmountBreakdown(

            lines: _breakdownLines(bundle, price),

            totalKrw: price,

          ),

          Container(

            color: AppColors.surface,

            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),

            child: SafeArea(

              top: false,

              child: FilledButton(

                onPressed: _processing ? null : _pay,

                style: FilledButton.styleFrom(

                  backgroundColor: AppColors.primary,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 16),

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

                    : Text(

                        '$formatted원 $selectedLabel 결제',

                        style: const TextStyle(

                          fontWeight: FontWeight.w700,

                          fontSize: 15,

                        ),

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

                  child: const Icon(

                    Icons.campaign_rounded,

                    color: AppColors.primary,

                  ),

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        '푸시 알림 · ${bundle.productSummary}',

                        style: const TextStyle(

                          fontSize: 16,

                          fontWeight: FontWeight.w800,

                          color: AppColors.textPrimary,

                        ),

                      ),

                      const SizedBox(height: 4),

                      Text(

                        _bundleDetail(bundle),

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



  static String _bundleDetail(PushPaymentBundle bundle) {

    if (bundle.isExtraPush) {

      return '기본 일일 푸시 한도 초과 · 패키지 1회 발송\n'

          '추가 공고 노출 범위·지원자 모집하기는 패키지 구매로 확장';

    }

    return '반경 ${bundle.radiusTier.label}\n'

        '지정 ${bundle.pointTier.label} · ${bundle.spotCount}곳';

  }

}


