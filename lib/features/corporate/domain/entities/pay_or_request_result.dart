import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';

enum PayOrRequestOutcome {
  paid,
  requestSent,
  cancelled,
  blocked,
  notRequired,
}

class PayOrRequestResult {
  const PayOrRequestResult({
    required this.outcome,
    this.payment,
    this.request,
    this.message,
  });

  final PayOrRequestOutcome outcome;
  final PaymentCompletionResult? payment;
  final JobPostPaymentRequest? request;
  final String? message;

  bool get isRequestSent => outcome == PayOrRequestOutcome.requestSent;
  bool get isPaid => outcome == PayOrRequestOutcome.paid;
}
