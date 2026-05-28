import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// 공고 결제 내역 (내부 결재·PDF 보고용)
class JobPostPaymentRecord {
  const JobPostPaymentRecord({
    required this.orderId,
    required this.productName,
    required this.amountKrw,
    required this.method,
    required this.transactionId,
    required this.paidAt,
    required this.radiusTier,
  });

  final String orderId;
  final String productName;
  final int amountKrw;
  final PaymentMethod method;
  final String transactionId;
  final DateTime paidAt;
  final PushRadiusTier radiusTier;

  String get formattedAmountKrw {
    final formatted = amountKrw.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$formatted원';
  }
}

/// 결제 완료 후 작성 화면으로 전달
class PaymentCompletionResult {
  const PaymentCompletionResult({
    required this.record,
  });

  final JobPostPaymentRecord record;
}
