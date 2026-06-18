import 'package:flutter/material.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/entities/payment_request.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/recruitment_product_kind.dart';
import 'package:map/features/corporate/domain/services/corporate_tax_document_service.dart';
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
    final qty = offer.supportsQuantitySelector ? quantity.clamp(1, 99) : 1;
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

    if (EnvConfig.isComplianceApiEnabled &&
        offer.kind == RecruitmentProductKind.exposureOnly) {
      try {
        await IljariApiClient().addPackageCredits(
          companyKey: profile.companyKey,
          count: totalCredits,
          locationSlots: totalCredits,
        );
      } on Object {
        return PushPackagePurchaseResult(
          success: false,
          message: '결제는 완료됐지만 서버 지갑 충전에 실패했습니다. 고객센터로 문의해 주세요.',
          transactionId: payment.transactionId ?? request.orderId,
        );
      }
    }

    await _walletService.addPurchase(
      profile: profile,
      offer: offer,
      quantity: qty,
    );

    final category = switch (offer.kind) {
      RecruitmentProductKind.pushOnly => PaymentProductCategory.pushTicket,
      RecruitmentProductKind.exposureWithPush =>
        PaymentProductCategory.pushNotification,
      RecruitmentProductKind.exposureOnly =>
        PaymentProductCategory.pushPackage,
    };

    await CorporateTaxDocumentService().recordPayment(
      context: PaymentRequestContext(
        orderId: request.orderId,
        productName: request.productName,
        amountKrw: totalKrw,
        method: method,
        category: category,
        transactionId: payment.transactionId,
        profile: profile,
        buyerEmail: AuthSession.instance.currentUser?.email,
      ),
    );

    await _clearLegacySubscription(profile);

    return PushPackagePurchaseResult(
      success: true,
      transactionId: payment.transactionId ?? request.orderId,
      message: '${offer.productName} $totalCredits회가 충전되었습니다.',
    );
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
