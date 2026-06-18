import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// A가 B에게 보낼 결제 요청 한 줄
class JobPostPaymentLineItem {
  const JobPostPaymentLineItem({
    required this.label,
    required this.detail,
    required this.amountKrw,
    required this.bundle,
    required this.kind,
  });

  final String label;
  final String detail;
  final int amountKrw;
  final PushPaymentBundle bundle;
  final JobPostPaymentRequestKind kind;

  String get amountLabel =>
      '${amountKrw.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원';
}
