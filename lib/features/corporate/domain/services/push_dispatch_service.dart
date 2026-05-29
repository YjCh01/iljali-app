import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

/// 푸시 발송 — 공고 등록 무료 · 모집하기 시 지역 푸시권/일일 무료 소진
class PushDispatchService {
  PushDispatchService({PushWalletService? walletService})
      : _walletService = walletService ?? PushWalletService();

  final PushWalletService _walletService;

  /// 공고 등록 — 무료 (크레딧 소진 없음)
  Future<PushDispatchPrepareResult?> prepareRegistrationPush({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required JobPostNotificationSettings settings,
  }) async {
    if (!settings.hasConfiguredBase) {
      return const PushDispatchPrepareResult(
        radiusTier: PushRadiusTier.standardFree1km,
        paymentKrw: 0,
        source: PushConsumeSource.dailyFree,
        recruitmentPushCount: 0,
      );
    }

    return PushDispatchPrepareResult(
      radiusTier: PushRadiusTier.standardFree1km,
      paymentKrw: 0,
      source: PushConsumeSource.dailyFree,
      recruitmentPushCount:
          PushWalletCreditPolicy.recruitmentZoneCount(settings),
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
          content: Text('먼저 모집지역을 설정해 주세요.'),
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
        radiusTier: activePointIndex > 0
            ? PushRadiusTier.standard1km
            : PushRadiusTier.standardFree1km,
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
            '모집지역 $paidRequired곳 추가·변경에 지역 푸시권 $paidRequired회가 필요합니다.',
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
          content: Text(paid.message ?? '지역 푸시권이 부족합니다.'),
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
          title: const Text('모집지역이 지역 푸시권 범위를 초과합니다'),
          content: Text(
            '설정된 노출 ${settings.basePoints.length}곳 · '
            '설정 가능 ${maxPoints}곳\n\n'
            '「모집지역 설정」에서 지역을 줄이거나 지역 푸시권을 구매해 주세요.',
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

    if (wallet.packageCredits < cost.packageCreditsRequired) {
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
      if (wallet.packageCredits < cost.packageCreditsRequired) {
        return null;
      }
    }

    PushConsumeSource? workplaceSource;
    if (cost.recruitmentZones > 0) {
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
      final paid = await _walletService.tryConsumeRecruitmentCredits(
        current,
        cost.recruitmentZones,
      );
      if (!paid.success) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(paid.message ?? '지역 푸시권이 부족합니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      workplaceSource = PushConsumeSource.packageCredit;
    } else if (cost.usesDailyFreeWorkplace) {
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
      final workplace =
          await _walletService.tryConsumeDailyFreeWorkplacePush(current);
      if (!workplace.success) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(workplace.message ?? '근무지 푸시를 보낼 수 없습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      workplaceSource = workplace.source;
    } else if (cost.packageCreditsRequired > 0) {
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
      final workplace =
          await _walletService.tryConsumeRecruitmentCredit(current);
      if (!workplace.success) {
        if (!context.mounted) return null;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(workplace.message ?? '지역 푸시권이 부족합니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return null;
      }
      workplaceSource = workplace.source;
    }

    final usesFreeRadius =
        cost.usesDailyFreeWorkplace && cost.recruitmentZones == 0;

    return PushDispatchPrepareResult(
      radiusTier: usesFreeRadius
          ? PushRadiusTier.standardFree1km
          : PushRadiusTier.standard1km,
      paymentKrw: 0,
      source: workplaceSource ?? PushConsumeSource.packageCredit,
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
        title: const Text('지역 푸시권 충전'),
        content: Text(
          '$message\n\n'
          '지역 푸시권 1회 = 추가 모집지역 푸시 1곳 · $unit\n'
          '근무지 1km는 기본 포함 · 구매 즉시 모집에 사용할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('나중에'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('지역 푸시권 ${qty}회 구매'),
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
        content: Text('지역 푸시권 ${qty}회가 충전되었습니다. 바로 모집할 수 있어요.'),
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
  });

  final PushRadiusTier radiusTier;
  final int paymentKrw;
  final PushConsumeSource source;
  final JobPostPaymentRecord? paymentRecord;
  final int recruitmentPushCount;
  final ZonePushCreditSummary? zoneChangeSummary;
}
