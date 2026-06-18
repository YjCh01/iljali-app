import 'package:flutter/material.dart';
import 'package:map/core/config/payment_gateway_factory.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/services/remote_payments_gateway_service.dart';
import 'package:map/features/corporate/data/services/toss_payments_gateway_service.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';
import 'package:map/features/corporate/presentation/pages/payment_checkout_page.dart';

/// 결제 요청 → checkout WebView → confirm까지 처리
class PaymentFlowHelper {
  PaymentFlowHelper({PaymentGatewayService? gateway})
      : _gateway = gateway ?? PaymentGatewayFactory.create();

  final PaymentGatewayService _gateway;

  Future<PaymentResult> pay(
    BuildContext context,
    PaymentRequest request,
  ) async {
    final enriched = PaymentRequest(
      orderId: request.orderId,
      productName: request.productName,
      amountKrw: request.amountKrw,
      method: request.method,
      radiusTier: request.radiusTier,
      buyerEmail: request.buyerEmail ??
          AuthSession.instance.currentUser?.email,
      buyerName: request.buyerName ??
          AuthSession.instance.currentUser?.name,
      companyKey: request.companyKey ??
          AuthSession.instance.currentUser?.corporateProfile?.companyKey,
    );

    final result = await _gateway.requestPayment(enriched);
    if (!result.success) return result;

    if (enriched.usesSavedCard) {
      return PaymentResult(
        success: true,
        transactionId: result.transactionId ?? enriched.orderId,
        mock: result.mock,
      );
    }

    if (result.mock || result.checkoutUrl == null) {
      return PaymentResult(
        success: true,
        transactionId: result.transactionId ?? enriched.orderId,
        mock: result.mock,
      );
    }

    if (!context.mounted) return PaymentResult.fail('화면이 종료되었습니다.');

    final paymentKey = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => PaymentCheckoutPage(
          checkoutUrl: result.checkoutUrl!,
          request: enriched,
        ),
      ),
    );

    if (paymentKey == null || paymentKey.isEmpty) {
      return PaymentResult.fail('결제가 취소되었습니다.');
    }

    if (_gateway is RemotePaymentsGatewayService) {
      return (_gateway as RemotePaymentsGatewayService).confirmViaServer(
        paymentKey: paymentKey,
        orderId: enriched.orderId,
        amountKrw: enriched.amountKrw,
      );
    }

    if (_gateway is TossPaymentsGatewayService) {
      return (_gateway as TossPaymentsGatewayService).confirmViaServer(
        paymentKey: paymentKey,
        orderId: enriched.orderId,
        amountKrw: enriched.amountKrw,
      );
    }

    return PaymentResult.ok(paymentKey);
  }
}
