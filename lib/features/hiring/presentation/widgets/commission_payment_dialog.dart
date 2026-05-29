import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/trust/presentation/employer_rating_dialog.dart';
import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';

/// 구직자 출근 확인 후 기업 수수료 결제 다이얼로그
Future<bool?> showCommissionPaymentDialog(
  BuildContext context,
  HiringApplication application,
) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CommissionPaymentDialog(application: application),
  );
}

class CommissionPaymentDialog extends StatefulWidget {
  const CommissionPaymentDialog({
    super.key,
    required this.application,
  });

  final HiringApplication application;

  @override
  State<CommissionPaymentDialog> createState() =>
      _CommissionPaymentDialogState();
}

class _CommissionPaymentDialogState extends State<CommissionPaymentDialog> {
  PaymentMethod _method = PaymentMethod.card;
  bool _processing = false;

  int get _amount =>
      widget.application.commissionAmountKrw ?? CommissionCalculator.defaultKrw();

  Future<void> _pay() async {
    setState(() => _processing = true);
    final result = await PaymentFlowHelper().pay(
      context,
      PaymentRequest(
        orderId: 'COMM-${DateTime.now().millisecondsSinceEpoch}',
        productName: '일용직 출근 확인 수수료 · ${widget.application.seekerName}',
        amountKrw: _amount,
        method: _method,
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
    final repo = await LocalHiringRepository.create();
    await repo.markCommissionPaid(widget.application.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile != null && context.mounted) {
      await showEmployerRatingDialog(
        context,
        widget.application,
        companyKey: profile.companyKey,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.application;
    final formatted = CommissionCalculator.formatKrw(_amount);

    return AlertDialog(
      title: const Text('일용직 출근 확인 · 수수료'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${app.seekerName}님과 상호 출근 확인이 완료되었습니다.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('공고: ${app.postTitle}'),
            if (app.checkedInAt != null)
              Text(
                '구직자 출근: ${app.checkedInAt!.hour.toString().padLeft(2, '0')}:'
                '${app.checkedInAt!.minute.toString().padLeft(2, '0')}',
              ),
            if (app.employerConfirmedAt != null)
              Text(
                '기업 확인: ${app.employerConfirmedAt!.hour.toString().padLeft(2, '0')}:'
                '${app.employerConfirmedAt!.minute.toString().padLeft(2, '0')}',
              ),
            const SizedBox(height: 8),
            const Text(
              '상호 확인 후에만 성공 수수료(일용직 출근 확인)가 청구됩니다.',
              style: TextStyle(fontSize: 12, height: 1.4),
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
                    '일용직 출근 확인 수수료 $formatted',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CommissionCalculator.feeDescription(),
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
            Text(
              '※ 결제를 미루면 알림이 반복되고, 고객센터 ARS로 자동 연락됩니다.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary.withValues(alpha: 0.9),
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
