import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/services/corporate_tax_document_service.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

/// PUSH 발송 — 대상 1곳 선택 + PUSH 알림권(19,900원) 결제/소진
class PushDispatchService {
  PushDispatchService({PushWalletService? walletService})
      : _walletService = walletService ?? PushWalletService();

  final PushWalletService _walletService;

  /// 거점 설정 직후 자동 PUSH 없음 — 레거시 호환용 메타데이터만 반환.
  ///
  /// 실제 PUSH는 [prepareQuickRecruitPush] (공고 탭 「모집하기」)에서만 실행.
  Future<PushDispatchPrepareResult?> prepareRegistrationPush({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required JobPostNotificationSettings settings,
  }) async {
    if (!settings.hasConfiguredBase) {
      return const PushDispatchPrepareResult(
        radiusTier: PushRadiusTier.standard1km,
        paymentKrw: 0,
        source: PushConsumeSource.packageCredit,
        recruitmentPushCount: 0,
      );
    }

    return const PushDispatchPrepareResult(
      radiusTier: PushRadiusTier.standard1km,
      paymentKrw: 0,
      source: PushConsumeSource.packageCredit,
      recruitmentPushCount: 0,
    );
  }

  /// 공고관리 — 저장된 모집지역으로 즉시 발송
  Future<PushDispatchPrepareResult?> prepareQuickRecruitPush({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required JobPostNotificationSettings settings,
  }) async {
    if (!settings.hasConfiguredBase) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('먼저 일자리 알림핀을 설정해 주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    return _prepareAndConsumeQuickRecruit(
      context: context,
      profile: profile,
      settings: settings,
    );
  }

  /// 공고관리 — 대상 1곳 선택 후 PUSH권 결제/소진
  Future<PushDispatchPrepareResult?> prepareTargetedDispatch({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required CorporateJobPost post,
    required PushDispatchTarget target,
    required PushTargetPaymentMode paymentMode,
  }) async {
    if (paymentMode != PushTargetPaymentMode.comboIncluded) {
      final blockReason = ExposureSlotPolicy.pushTicketBlockReason(
        post: post,
        target: target,
      );
      if (blockReason != null) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(blockReason),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
    }

    var current = profile;
    var paymentKrw = 0;

    if (paymentMode == PushTargetPaymentMode.walletCredit) {
      final consumed = await _walletService.tryConsumePushTicket(current);
      if (!consumed.success) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(consumed.message ?? 'PUSH 알림권이 부족합니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
    } else if (paymentMode == PushTargetPaymentMode.pgPayment) {
      final paid = await _payForPushTicket(context: context, profile: current);
      if (!paid) return null;
      paymentKrw = PushTicketCatalog.unitPriceKrw;
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    }

    final radiusTier = switch (target.kind) {
      PushDispatchTargetKind.workplace => PushRadiusTier.standardFree1km,
      _ => PushRadiusTier.standard1km,
    };

    return PushDispatchPrepareResult(
      radiusTier: radiusTier,
      paymentKrw: paymentKrw,
      source: PushConsumeSource.packageCredit,
      recruitmentPushCount: 0,
      target: target,
      jobPostId: post.id,
      jobTitle: post.title,
    );
  }

  /// 공고관리 — 대상 여러 곳 선택 후 PUSH권 일괄 결제/소진
  Future<PushDispatchPrepareResult?> prepareBatchTargetedDispatch({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required CorporateJobPost post,
    required List<PushDispatchTarget> targets,
    required PushTargetPaymentMode paymentMode,
  }) async {
    if (targets.isEmpty) return null;

    if (paymentMode != PushTargetPaymentMode.comboIncluded) {
      for (final target in targets) {
        final blockReason = ExposureSlotPolicy.pushTicketBlockReason(
          post: post,
          target: target,
        );
        if (blockReason != null) {
          if (!context.mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(blockReason),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return null;
        }
      }
    }

    if (paymentMode == PushTargetPaymentMode.comboIncluded) {
      return prepareTargetedDispatch(
        context: context,
        profile: profile,
        post: post,
        target: targets.first,
        paymentMode: paymentMode,
      );
    }

    var current = profile;
    var paymentKrw = 0;

    if (paymentMode == PushTargetPaymentMode.walletCredit) {
      for (var i = 0; i < targets.length; i++) {
        final consumed = await _walletService.tryConsumePushTicket(current);
        if (!consumed.success) {
          if (!context.mounted) return null;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                consumed.message ??
                    'PUSH 알림권이 부족합니다. (${i}/${targets.length}곳 처리됨)',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return null;
        }
        current =
            AuthSession.instance.currentUser?.corporateProfile ?? current;
      }
    } else if (paymentMode == PushTargetPaymentMode.pgPayment) {
      for (var i = 0; i < targets.length; i++) {
        final paid = await _payForPushTicket(context: context, profile: current);
        if (!paid) return null;
        paymentKrw += PushTicketCatalog.unitPriceKrw;
        current =
            AuthSession.instance.currentUser?.corporateProfile ?? current;
      }
    }

    final primary = targets.first;
    final radiusTier = switch (primary.kind) {
      PushDispatchTargetKind.workplace => PushRadiusTier.standardFree1km,
      _ => PushRadiusTier.standard1km,
    };

    return PushDispatchPrepareResult(
      radiusTier: radiusTier,
      paymentKrw: paymentKrw,
      source: PushConsumeSource.packageCredit,
      recruitmentPushCount: targets.length,
      target: primary,
      jobPostId: post.id,
      jobTitle: post.title,
    );
  }

  Future<bool> _payForPushTicket({
    required BuildContext context,
    required CorporateMemberProfile profile,
  }) async {
    if (!context.mounted) return false;

    final paymentResult =
        await Navigator.of(context).pushNamed<PaymentCompletionResult>(
      AppRoutes.corporateNotificationPayment,
      arguments: const PushPaymentBundle.pushTicket(),
    );
    if (paymentResult == null) return false;

    await CorporateTaxDocumentService().recordPayment(
      context: PaymentRequestContext(
        orderId: paymentResult.record.orderId,
        productName: '${PushTicketCatalog.productName} · 1회',
        amountKrw: PushTicketCatalog.unitPriceKrw,
        method: paymentResult.record.method,
        category: PaymentProductCategory.pushTicket,
        transactionId: paymentResult.record.transactionId,
        profile: profile,
        buyerEmail: AuthSession.instance.currentUser?.email,
      ),
    );

    return true;
  }

  /// 공고관리 — 지역 변경·재발송
  Future<PushDispatchPrepareResult?> prepareExtraPush({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required List<PushNotificationBasePoint> beforePoints,
    required List<PushNotificationBasePoint> afterPoints,
    required int activePointIndex,
  }) async {
    final summary = PushWalletCreditPolicy.extraPushCreditsRequired(
      before: beforePoints,
      after: afterPoints,
    );
    final paidRequired = PushWalletCreditPolicy.extraPushBillableCredits(
      before: beforePoints,
      after: afterPoints,
      activePointIndex: activePointIndex,
    );

    if (paidRequired <= 0) {
      return PushDispatchPrepareResult(
        radiusTier: PushRadiusTier.standard1km,
        paymentKrw: 0,
        source: PushConsumeSource.packageCredit,
        recruitmentPushCount: 0,
        zoneChangeSummary: summary.structureChanged ? summary : null,
      );
    }

    var current = profile;
    var wallet = await _walletService.loadWallet(current);
    if (wallet.packageCredits < paidRequired) {
      if (!context.mounted) return null;
      final ok = await _promptPackagePurchase(
        context: context,
        profile: current,
        shortfall: paidRequired - wallet.packageCredits,
        message:
            '일자리 알림핀 $paidRequired곳 추가·변경에 일자리 알림핀 $paidRequired회가 필요합니다.',
      );
      if (!ok || !context.mounted) return null;
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
      wallet = await _walletService.loadWallet(current);
      if (wallet.packageCredits < paidRequired) return null;
    }

    current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    final paid = await _walletService.tryConsumeRecruitmentCredits(
      current,
      paidRequired,
    );
    if (!paid.success) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paid.message ?? '일자리 알림핀이 부족합니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    return PushDispatchPrepareResult(
      radiusTier: PushRadiusTier.standard1km,
      paymentKrw: 0,
      source: PushConsumeSource.packageCredit,
      recruitmentPushCount: paidRequired,
      zoneChangeSummary: summary.structureChanged ? summary : null,
    );
  }

  Future<PushDispatchPrepareResult?> _prepareAndConsumeQuickRecruit({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required JobPostNotificationSettings settings,
  }) async {
    var current = profile;
    var wallet = await _walletService.loadWallet(current);
    final cost = PushWalletCreditPolicy.quickRecruitDispatchCost(
      settings: settings,
      wallet: wallet,
    );

    if (settings.basePoints.length >
        PushWalletCreditPolicy.effectiveMaxExposurePoints(
          wallet: wallet,
          currentPointsLength: settings.basePoints.length,
        )) {
      if (!context.mounted) return null;
      final maxPoints = PushWalletCreditPolicy.effectiveMaxExposurePoints(
        wallet: wallet,
        currentPointsLength: settings.basePoints.length,
      );
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('일자리 알림핀이 이용권 범위를 초과합니다'),
          content: Text(
            '설정된 노출 ${settings.basePoints.length}곳 · '
            '설정 가능 ${maxPoints}곳\n\n'
            '「일자리 알림핀 설정」에서 지역을 줄이거나 이용권을 구매해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        ),
      );
      return null;
    }

    if (!cost.canAffordFull(wallet)) {
      if (!context.mounted) return null;
      final ok = await _promptPackagePurchase(
        context: context,
        profile: current,
        shortfall: cost.packageCreditsRequired - wallet.packageCredits,
        message: cost.purchasePromptMessage(
          packageCreditsHeld: wallet.packageCredits,
        ),
      );
      if (!ok || !context.mounted) return null;
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
      wallet = await _walletService.loadWallet(current);
      if (!cost.canAffordFull(wallet)) {
        return null;
      }
    }

    current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    final paid = await _walletService.tryConsumeRecruitmentCredits(
      current,
      cost.packageCreditsRequired,
    );
    if (!paid.success) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(paid.message ?? '일자리 알림핀이 부족합니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return null;
    }

    return PushDispatchPrepareResult(
      radiusTier: PushRadiusTier.standard1km,
      paymentKrw: 0,
      source: PushConsumeSource.packageCredit,
      recruitmentPushCount: cost.recruitmentZones,
    );
  }

  Future<bool> _promptPackagePurchase({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required int shortfall,
    required String message,
  }) async {
    final qty = shortfall.clamp(1, 99);
    final unit = PushPackageCatalog.krwSuffix(
      PushPackageCatalog.singlePackagePriceKrw,
    );

    final goShop = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('일자리 알림핀 충전'),
        content: Text(
          '$message\n\n'
          '일자리 알림핀 1회 = 근무지·일자리 알림핀 PUSH 1곳 · $unit\n'
          '구매 시 지갑에 충전 · 공고목록 「모집하기」에서 사용합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('일자리 알림핀 ${qty}회 구매'),
          ),
        ],
      ),
    );

    if (goShop != true || !context.mounted) return false;

    final paymentResult =
        await Navigator.of(context).pushNamed<PaymentCompletionResult>(
      AppRoutes.corporateNotificationPayment,
      arguments: PushPaymentBundle.extraPush(
        feeKrw: PushPackageCatalog.singlePackagePriceKrw * qty,
      ),
    );
    if (paymentResult == null) return false;

    var current = AuthSession.instance.currentUser?.corporateProfile ?? profile;
    final single =
        PushPackageCatalog.findById(PushPackageCatalog.singlePackageId)!;
    await _walletService.addPurchase(
      profile: current,
      offer: single,
      quantity: qty,
    );

    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('일자리 알림핀 ${qty}회가 지갑에 충전되었습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return true;
  }
}

class PushDispatchPrepareResult {
  const PushDispatchPrepareResult({
    required this.radiusTier,
    required this.paymentKrw,
    required this.source,
    this.paymentRecord,
    this.recruitmentPushCount = 0,
    this.zoneChangeSummary,
    this.target,
    this.jobPostId,
    this.jobTitle,
  });

  final PushRadiusTier radiusTier;
  final int paymentKrw;
  final PushConsumeSource source;
  final JobPostPaymentRecord? paymentRecord;
  final int recruitmentPushCount;
  final ZonePushCreditSummary? zoneChangeSummary;
  final PushDispatchTarget? target;
  final String? jobPostId;
  final String? jobTitle;
}

enum PushTargetPaymentMode {
  walletCredit,
  pgPayment,

  /// 노출+PUSH 번들에 포함된 1회 — 추가 차감 없음
  comboIncluded,
}
