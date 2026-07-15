import 'package:flutter/material.dart';
import 'package:map/core/config/payment_gateway_factory.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/services/remote_payments_gateway_service.dart';
import 'package:map/features/corporate/data/services/toss_payments_gateway_service.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/services/employer_cash_balance_service.dart';
import 'package:map/features/corporate/domain/services/payment_gateway_service.dart';
import 'package:map/features/corporate/presentation/pages/payment_checkout_page.dart';

/// 결제 요청 → checkout WebView → confirm까지 처리
class PaymentFlowHelper {
  PaymentFlowHelper({PaymentGatewayService? gateway})
      : _gateway = gateway ?? PaymentGatewayFactory.create();

  final PaymentGatewayService _gateway;

  Future<PaymentResult> pay(
    BuildContext context,
    PaymentRequest request, {
    bool allowCashBalance = true,
  }) async {
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
      savedPaymentMethodId: request.savedPaymentMethodId,
      billingKey: request.billingKey,
      creditType: request.creditType,
      creditCount: request.creditCount,
      creditLocationSlots: request.creditLocationSlots,
    );

    var amountKrw = enriched.amountKrw;
    var usedCashKrw = 0;

    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (allowCashBalance && profile != null && amountKrw > 0) {
      final cash = await EmployerCashBalanceService().tryPayWithBalance(
        profile: profile,
        amountKrw: amountKrw,
      );
      usedCashKrw = cash.usedCashKrw;
      amountKrw = cash.remainingKrw;
      if (cash.success) {
        return PaymentResult(
          success: true,
          transactionId: 'cash-${enriched.orderId}',
          usedCashKrw: usedCashKrw,
        );
      }
    }

    if (amountKrw <= 0) {
      return PaymentResult(
        success: true,
        transactionId: 'cash-${enriched.orderId}',
        usedCashKrw: usedCashKrw,
      );
    }

    final payable = PaymentRequest(
      orderId: enriched.orderId,
      productName: enriched.productName,
      amountKrw: amountKrw,
      method: enriched.method,
      radiusTier: enriched.radiusTier,
      buyerEmail: enriched.buyerEmail,
      buyerName: enriched.buyerName,
      companyKey: enriched.companyKey,
      savedPaymentMethodId: enriched.savedPaymentMethodId,
      billingKey: enriched.billingKey,
      creditType: enriched.creditType,
      creditCount: enriched.creditCount,
      creditLocationSlots: enriched.creditLocationSlots,
    );

    final result = await _gateway.requestPayment(payable);
    if (!result.success) return result;

    if (payable.usesSavedCard) {
      return PaymentResult(
        success: true,
        transactionId: result.transactionId ?? payable.orderId,
        mock: result.mock,
        usedCashKrw: usedCashKrw,
      );
    }

    if (result.mock || result.checkoutUrl == null) {
      return PaymentResult(
        success: true,
        transactionId: result.transactionId ?? payable.orderId,
        mock: result.mock,
        usedCashKrw: usedCashKrw,
      );
    }

    if (!context.mounted) return PaymentResult.fail('화면이 종료되었습니다.');

    final paymentKey = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => PaymentCheckoutPage(
          checkoutUrl: result.checkoutUrl!,
          request: payable,
        ),
      ),
    );

    if (paymentKey == null || paymentKey.isEmpty) {
      return PaymentResult.fail('결제가 취소되었습니다.');
    }

    PaymentResult confirmed;
    if (_gateway is RemotePaymentsGatewayService) {
      confirmed = await (_gateway as RemotePaymentsGatewayService).confirmViaServer(
        paymentKey: paymentKey,
        orderId: payable.orderId,
        amountKrw: payable.amountKrw,
        creditType: payable.creditType,
        creditCount: payable.creditCount,
        creditLocationSlots: payable.creditLocationSlots,
      );
    } else if (_gateway is TossPaymentsGatewayService) {
      confirmed = await (_gateway as TossPaymentsGatewayService).confirmViaServer(
        paymentKey: paymentKey,
        orderId: payable.orderId,
        amountKrw: payable.amountKrw,
        creditType: payable.creditType,
        creditCount: payable.creditCount,
        creditLocationSlots: payable.creditLocationSlots,
      );
    } else {
      confirmed = PaymentResult.ok(paymentKey);
    }

    if (!confirmed.success) return confirmed;
    return PaymentResult(
      success: true,
      transactionId: confirmed.transactionId ?? paymentKey,
      mock: confirmed.mock,
      usedCashKrw: usedCashKrw,
    );
  }
}
