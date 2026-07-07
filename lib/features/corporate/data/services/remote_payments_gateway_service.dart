import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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
      if (kReleaseMode && !EnvConfig.qcMode) {
        return PaymentResult.fail('결제 서버가 설정되지 않았습니다.');
      }
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
          if (kIsWeb) 'web_checkout': true,
          if (request.billingKey != null) 'billing_key': request.billingKey,
          if (request.savedPaymentMethodId != null)
            'saved_method_id': request.savedPaymentMethodId,
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
      if (kReleaseMode && !EnvConfig.qcMode) {
        return PaymentResult.fail('결제 서버에 연결할 수 없습니다.');
      }
      return _fallback.requestPayment(request);
    }
  }

  /// checkout WebView success 후 서버에서 토스 승인 확인
  Future<PaymentResult> confirmViaServer({
    required String paymentKey,
    required String orderId,
    required int amountKrw,
  }) async {
    if (_baseUrl.isEmpty) {
      return PaymentResult.ok('REMOTE-LOCAL-$orderId');
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/v1/payments/confirm'),
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
        mock: map['mock'] as bool? ?? false,
      );
    } on Object {
      return PaymentResult.fail('결제 승인 통신 오류');
    }
  }
}
