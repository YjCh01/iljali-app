import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/services/mock_payment_gateway_service.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';

/// 토스페이먼츠 결제위젯 연동 준비 — 클라이언트 키로 checkout URL 생성
class TossPaymentsGatewayService implements PaymentGatewayService {
  TossPaymentsGatewayService({http.Client? client})
      : _client = client ?? http.Client(),
        _fallback = const MockPaymentGatewayService();

  final http.Client _client;
  final MockPaymentGatewayService _fallback;

  static const _widgetBase = 'https://pay.toss.im/web/payment';

  @override
  Future<PaymentResult> requestPayment(PaymentRequest request) async {
    final clientKey = EnvConfig.tossPaymentsClientKey;
    if (clientKey.isEmpty) {
      return _fallback.requestPayment(request);
    }

    try {
      final checkoutUrl = Uri.parse(_widgetBase).replace(queryParameters: {
        'clientKey': clientKey,
        'orderId': request.orderId,
        'amount': '${request.amountKrw}',
        'orderName': request.productName,
        'successUrl': 'iljari://payment/success',
        'failUrl': 'iljari://payment/fail',
      }).toString();

      return PaymentResult(
        success: true,
        checkoutUrl: checkoutUrl,
        paymentKey: 'pending-${request.orderId}',
        mock: false,
      );
    } on Object {
      return _fallback.requestPayment(request);
    }
  }

  /// 결제위젯 successUrl 수신 후 서버 confirm (secret key는 서버만 보유)
  Future<PaymentResult> confirmViaServer({
    required String paymentKey,
    required String orderId,
    required int amountKrw,
  }) async {
    if (!EnvConfig.isComplianceApiEnabled) {
      return PaymentResult.ok('TOSS-LOCAL-$orderId');
    }

    final base = EnvConfig.complianceApiBaseUrl.replaceAll(RegExp(r'/$'), '');
    final response = await _client.post(
      Uri.parse('$base/v1/payments/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'payment_key': paymentKey,
        'order_id': orderId,
        'amount_krw': amountKrw,
      }),
    );

    if (response.statusCode >= 400) {
      return PaymentResult.fail('결제 승인 실패');
    }
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return PaymentResult(
      success: map['success'] as bool? ?? false,
      transactionId: map['transaction_id'] as String?,
    );
  }
}
