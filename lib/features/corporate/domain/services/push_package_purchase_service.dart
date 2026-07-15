import 'package:flutter/material.dart';
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
    final blocked = profile.paidServicesBlockedReason;
    if (blocked != null) {
      return PushPackagePurchaseResult(success: false, message: blocked);
    }

    final qty = offer.supportsQuantitySelector ? quantity.clamp(1, 99) : 1;
    final totalKrw = offer.priceKrw * qty;
    final totalCredits = offer.packageCount * qty;

    final request = PaymentRequest(
      orderId: 'PKG-${offer.id}-${DateTime.now().millisecondsSinceEpoch}',
      productName: qty > 1 ? '${offer.productName} ×$qty' : offer.productName,
      amountKrw: totalKrw,
      method: method,
      companyKey: profile.companyKey,
      creditType: offer.kind.serverCreditType,
      creditCount: totalCredits,
      creditLocationSlots:
          offer.kind == RecruitmentProductKind.exposureOnly ? totalCredits : null,
    );

    final payment = await _paymentFlow.pay(context, request);
    if (!payment.success) {
      return PushPackagePurchaseResult(
        success: false,
        message: payment.message ?? '결제에 실패했습니다.',
      );
    }

    // 결제 confirm 시점에 서버가 지갑 크레딧을 이미 지급했으므로(1v1 confirm이 유일한
    // 지급 경로), 서버 연동 환경에서는 서버 값을 읽어와 로컬에 반영한다. 서버
    // 미연동(QC/로컬 개발) 환경에서만 로컬 지갑을 직접 증가시킨다.
    if (EnvConfig.isComplianceApiEnabled) {
      await _walletService.refreshFromServer(profile);
    } else {
      await _walletService.addPurchase(
        profile: profile,
        offer: offer,
        quantity: qty,
      );
    }

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
