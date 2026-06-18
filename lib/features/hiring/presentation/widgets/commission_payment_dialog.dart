import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/trust/presentation/employer_rating_dialog.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_method_option.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/services/corporate_tax_document_service.dart';
import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';
import 'package:map/features/corporate/presentation/pages/corporate_tax_documents_page.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_amount_breakdown.dart';
import 'package:map/features/corporate/presentation/widgets/payment/payment_method_selection_section.dart';

/// 상호 출근 확인 후 채용 수수료 PG 결제 화면 (일자리 알림핀과 동일 checkout)
Future<bool?> showCommissionPaymentDialog(
  BuildContext context,
  HiringApplication application,
) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      builder: (_) => CommissionPaymentPage(application: application),
    ),
  );
}

class CommissionPaymentPage extends StatefulWidget {
  const CommissionPaymentPage({
    super.key,
    required this.application,
  });

  final HiringApplication application;

  @override
  State<CommissionPaymentPage> createState() => _CommissionPaymentPageState();
}

class _CommissionPaymentPageState extends State<CommissionPaymentPage> {
  PaymentMethod _method = PaymentMethodCatalog.defaultMethod;
  bool _processing = false;
  String? _error;

  HiringApplication get _app => widget.application;

  int get _amount => CommissionCalculator.forApplication(_app);

  String get _productLabel =>
      '채용 수수료 · ${_app.seekerName} (${_app.postTitle})';

  Future<void> _pay() async {
    setState(() {
      _processing = true;
      _error = null;
    });

    final orderId = 'COMM-${DateTime.now().millisecondsSinceEpoch}';
    final result = await PaymentFlowHelper().pay(
      context,
      PaymentRequest(
        orderId: orderId,
        productName: _productLabel,
        amountKrw: _amount,
        method: _method,
      ),
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        _processing = false;
        _error = result.message ?? '결제에 실패했습니다.';
      });
      return;
    }

    final repo = await LocalHiringRepository.create();
    await repo.markCommissionPaid(_app.id);
    if (!mounted) return;

    final profile = AuthSession.instance.currentUser?.corporateProfile;

    final taxDocs = await CorporateTaxDocumentService().recordPayment(
      context: PaymentRequestContext(
        orderId: orderId,
        productName: _productLabel,
        amountKrw: _amount,
        method: _method,
        category: PaymentProductCategory.hiringCommission,
        transactionId: result.transactionId,
        profile: profile,
        buyerEmail: AuthSession.instance.currentUser?.email,
        referenceId: _app.id,
      ),
    );

    Navigator.of(context).pop(true);

    if (context.mounted && taxDocs.isNotEmpty) {
      await showTaxDocumentsIssuedSnackBar(context, count: taxDocs.length);
    }

    if (profile != null && context.mounted) {
      await showEmployerRatingDialog(
        context,
        _app,
        companyKey: profile.companyKey,
      );
    }
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
        title: const Text('채용 수수료 결제'),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  '상호 출근 확인 완료',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_app.seekerName}님과 구인자·구직자 모두 출근확정이 완료되어 '
                  '1인당 채용 수수료가 청구됩니다.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.searchBarBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _app.postTitle,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_app.checkedInAt != null)
                        _DetailRow(
                          label: '구직자 출근',
                          value: _formatTime(_app.checkedInAt!),
                        ),
                      if (_app.employerConfirmedAt != null)
                        _DetailRow(
                          label: '기업 출근확정',
                          value: _formatTime(_app.employerConfirmedAt!),
                        ),
                      if (_app.mutuallyConfirmedAt != null)
                        _DetailRow(
                          label: '상호 확정',
                          value: _formatTime(_app.mutuallyConfirmedAt!),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        CommissionCalculator.feeDescription(),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textSecondary.withValues(alpha: 0.9),
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
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 8),
                Text(
                  '※ 결제를 미루면 알림이 반복되고, 고객센터 ARS로 자동 연락될 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          PaymentAmountBreakdown(
            lines: [
              PaymentBreakdownLine(
                label: _productLabel,
                amountKrw: _amount,
              ),
            ],
            totalKrw: _amount,
            totalLabel: '총 결제금액',
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
              child: Text(
                _processing
                    ? '결제 중...'
                    : '${PushPackageCatalog.krwSuffix(_amount)} · 채용 수수료 결제',
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
