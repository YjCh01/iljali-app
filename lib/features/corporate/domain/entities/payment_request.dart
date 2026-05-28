import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

/// PG 결제 요청 (실제 연동 시 orderId, buyerEmail 등 추가)
class PaymentRequest {
  const PaymentRequest({
    required this.orderId,
    required this.productName,
    required this.amountKrw,
    required this.method,
    this.radiusTier,
    this.buyerEmail,
    this.buyerName,
    this.companyKey,
  });

  final String orderId;
  final String productName;
  final int amountKrw;
  final PaymentMethod method;
  final PushRadiusTier? radiusTier;
  final String? buyerEmail;
  final String? buyerName;
  final String? companyKey;
}

class PaymentResult {
  const PaymentResult({
    required this.success,
    this.transactionId,
    this.message,
    this.checkoutUrl,
    this.paymentKey,
    this.mock = false,
  });

  final bool success;
  final String? transactionId;
  final String? message;
  final String? checkoutUrl;
  final String? paymentKey;
  final bool mock;

  static PaymentResult ok(String transactionId) => PaymentResult(
        success: true,
        transactionId: transactionId,
      );

  static PaymentResult fail(String message) => PaymentResult(
        success: false,
        message: message,
      );
}
