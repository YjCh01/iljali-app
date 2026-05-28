import 'package:flutter/material.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/payment_flow_helper.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

class PushPackagePurchaseResult {
  const PushPackagePurchaseResult({
    required this.success,
    this.message,
    this.transactionId,
  });

  final bool success;
  final String? message;
  final String? transactionId;
}

class PushPackagePurchaseService {
  PushPackagePurchaseService({
    PaymentFlowHelper? paymentFlow,
    PushWalletService? walletService,
  })  : _paymentFlow = paymentFlow ?? PaymentFlowHelper(),
        _walletService = walletService ?? PushWalletService();

  final PaymentFlowHelper _paymentFlow;
  final PushWalletService _walletService;

  Future<PushPackagePurchaseResult> purchase({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required PushPackageBundleOffer offer,
    required PaymentMethod method,
    int quantity = 1,
  }) async {
    final qty = _resolveQuantity(offer, quantity);
    final totalKrw = offer.priceKrw * qty;
    final totalCredits = offer.packageCount * qty;

    final request = PaymentRequest(
      orderId: 'PKG-${offer.id}-${DateTime.now().millisecondsSinceEpoch}',
      productName: qty > 1 ? '${offer.productName} ×$qty' : offer.productName,
      amountKrw: totalKrw,
      method: method,
      companyKey: profile.companyKey,
    );

    final payment = await _paymentFlow.pay(context, request);
    if (!payment.success) {
      return PushPackagePurchaseResult(
        success: false,
        message: payment.message ?? '결제에 실패했습니다.',
      );
    }

    await _walletService.addPurchase(
      profile: profile,
      offer: offer,
      quantity: qty,
    );

    await _clearLegacySubscription(profile);

    return PushPackagePurchaseResult(
      success: true,
      transactionId: payment.transactionId ?? request.orderId,
      message: '${offer.label} $totalCredits회가 충전되었습니다.',
    );
  }

  int _resolveQuantity(PushPackageBundleOffer offer, int quantity) {
    if (offer.id != PushPackageCatalog.singlePackageId) return 1;
    return quantity.clamp(1, 99);
  }

  Future<void> _clearLegacySubscription(CorporateMemberProfile profile) async {
    if (!profile.hasLegacyPaidSubscription) return;
    await AuthSession.instance.updateCorporateProfile(
      profile.copyWith(
        monthlySubscriptionActive: false,
        clearSubscriptionExpiresAt: true,
      ),
    );
  }
}
