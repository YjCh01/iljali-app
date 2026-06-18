import 'dart:math';

import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';

/// MVP용 mock PG — 실제 API 없이 결제 성공을 시뮬레이션합니다.
class MockPaymentGatewayService implements PaymentGatewayService {
  const MockPaymentGatewayService();

  @override
  Future<PaymentResult> requestPayment(PaymentRequest request) async {
    if (request.usesSavedCard) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final txnId =
          'MOCK-BILLING-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
      return PaymentResult.ok(txnId);
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final txnId =
        'MOCK-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}';
    return PaymentResult.ok(txnId);
  }
}
