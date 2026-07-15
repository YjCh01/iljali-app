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
    this.savedPaymentMethodId,
    this.billingKey,
    this.creditType,
    this.creditCount,
    this.creditLocationSlots,
  });

  final String orderId;
  final String productName;
  final int amountKrw;
  final PaymentMethod method;
  final PushRadiusTier? radiusTier;
  final String? buyerEmail;
  final String? buyerName;
  final String? companyKey;
  final String? savedPaymentMethodId;
  final String? billingKey;

  /// 구매 의도 — 결제 confirm 시 서버가 자동으로 지급할 지갑 크레딧.
  /// 알림핀/PUSH 이용권 등 크레딧성 상품에서만 채워짐.
  final String? creditType;
  final int? creditCount;
  final int? creditLocationSlots;

  bool get usesSavedCard =>
      billingKey != null && billingKey!.trim().isNotEmpty;
}

class PaymentResult {
  const PaymentResult({
    required this.success,
    this.transactionId,
    this.message,
    this.checkoutUrl,
    this.paymentKey,
    this.mock = false,
    this.usedCashKrw = 0,
  });

  final bool success;
  final String? transactionId;
  final String? message;
  final String? checkoutUrl;
  final String? paymentKey;
  final bool mock;
  final int usedCashKrw;

  static PaymentResult ok(String transactionId) => PaymentResult(
        success: true,
        transactionId: transactionId,
      );

  static PaymentResult fail(String message) => PaymentResult(
        success: false,
        message: message,
      );
}
