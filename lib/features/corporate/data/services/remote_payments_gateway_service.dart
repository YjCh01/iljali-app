import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/services/mock_payment_gateway_service.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';

/// FastAPI `/v1/payments/charge` 경유 결제 (서버에서 Toss 또는 mock)
class RemotePaymentsGatewayService implements PaymentGatewayService {
  RemotePaymentsGatewayService({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl)
            .replaceAll(RegExp(r'/$'), ''),
        _fallback = const MockPaymentGatewayService();

  final http.Client _client;
  final String _baseUrl;
  final MockPaymentGatewayService _fallback;

  @override
  Future<PaymentResult> requestPayment(PaymentRequest request) async {
    if (_baseUrl.isEmpty) {
      return _fallback.requestPayment(request);
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/payments/charge'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'order_id': request.orderId,
          'order_name': request.productName,
          'amount_krw': request.amountKrw,
          'method': request.method.pgProviderCode,
          'buyer_email': request.buyerEmail,
          'buyer_name': request.buyerName,
          'company_key': request.companyKey,
        }),
      );

      if (response.statusCode >= 400) {
        return PaymentResult.fail('결제 서버 오류 (${response.statusCode})');
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final success = map['success'] as bool? ?? false;
      if (!success) {
        return PaymentResult.fail(map['message']?.toString() ?? '결제 실패');
      }

      return PaymentResult(
        success: true,
        transactionId: map['transaction_id'] as String?,
        checkoutUrl: map['checkout_url'] as String?,
        paymentKey: map['payment_key'] as String?,
        mock: map['mock'] as bool? ?? false,
      );
    } on Object {
      return _fallback.requestPayment(request);
    }
  }
}
