import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/local_permanent_employment_repository.dart';
import 'package:map/core/hiring/monthly_commission.dart';
import 'package:map/core/hiring/permanent_commission_calculator.dart';
import 'package:map/core/hiring/permanent_employment_record.dart';
import 'package:map/core/hiring/permanent_commission_sync_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/corporate_tax_document_service.dart';
import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';

Future<bool?> showPermanentCommissionPaymentDialog(
  BuildContext context, {
  required PermanentEmploymentRecord employment,
  required MonthlyCommission commission,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PermanentCommissionPaymentDialog(
      employment: employment,
      commission: commission,
    ),
  );
}

class PermanentCommissionPaymentDialog extends StatefulWidget {
  const PermanentCommissionPaymentDialog({
    super.key,
    required this.employment,
    required this.commission,
  });

  final PermanentEmploymentRecord employment;
  final MonthlyCommission commission;

  @override
  State<PermanentCommissionPaymentDialog> createState() =>
      _PermanentCommissionPaymentDialogState();
}

class _PermanentCommissionPaymentDialogState
    extends State<PermanentCommissionPaymentDialog> {
  PaymentMethod _method = PaymentMethod.card;
  bool _processing = false;

  int get _amount => widget.commission.amountKrw;

  Future<void> _pay() async {
    setState(() => _processing = true);
    final result = await PaymentFlowHelper().pay(
      context,
      PaymentRequest(
        orderId: 'PERM-${widget.commission.id}',
        productName:
            '상시직 재직 확인 수수료 · ${widget.employment.seekerName}',
        amountKrw: _amount,
        method: _method,
        companyKey: widget.employment.companyKey,
      ),
    );
    if (!mounted) return;
    if (!result.success) {
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? '결제 실패')),
      );
      return;
    }

    final repo = await LocalPermanentEmploymentRepository.create();
    final paid = await repo.markCommissionCharged(
      widget.commission.id,
      chargedAt: DateTime.now(),
    );
    await PermanentCommissionSyncService().pushCommission(paid);

    await CorporateTaxDocumentService().recordPayment(
      context: PaymentRequestContext(
        orderId: 'PERM-${widget.commission.id}',
        productName:
            '상시직 재직 확인 수수료 · ${widget.employment.seekerName}',
        amountKrw: _amount,
        method: _method,
        category: PaymentProductCategory.permanentCommission,
        transactionId: result.transactionId,
        profile: AuthSession.instance.currentUser?.corporateProfile,
        buyerEmail: AuthSession.instance.currentUser?.email,
        referenceId: widget.commission.id,
      ),
    );

    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final formatted = PermanentCommissionCalculator.formatKrw(_amount);
    final periodEnd = DateFormat('yyyy.MM.dd').format(widget.commission.periodEnd);

    return AlertDialog(
      title: const Text('상시직 재직 확인 · 수수료'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.employment.seekerName}님 · ${periodEnd} 주기',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '월급 ${PermanentCommissionCalculator.formatKrw(widget.employment.monthlySalaryKrw)}',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '상시직 수수료 $formatted',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CommissionCalculator.feeDescription(isPermanentWorker: true),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...PaymentMethod.values.map(
              (method) => RadioListTile<PaymentMethod>(
                value: method,
                groupValue: _method,
                onChanged: _processing
                    ? null
                    : (value) => setState(() => _method = value!),
                title: Text(method.label),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _processing ? null : () => Navigator.of(context).pop(false),
          child: const Text('나중에'),
        ),
        FilledButton(
          onPressed: _processing ? null : _pay,
          child: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text('$formatted 결제'),
        ),
      ],
    );
  }
}
