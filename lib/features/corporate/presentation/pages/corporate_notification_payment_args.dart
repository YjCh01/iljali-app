import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// 결제 화면 라우트 인자
class CorporateNotificationPaymentArgs {
  const CorporateNotificationPaymentArgs({
    required this.bundle,
    this.paymentRequestId,
    this.paymentKind,
  });

  final PushPaymentBundle bundle;
  final String? paymentRequestId;
  final JobPostPaymentRequestKind? paymentKind;
}
