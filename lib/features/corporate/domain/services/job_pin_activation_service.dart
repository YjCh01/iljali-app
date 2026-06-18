import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_navigation_helper.dart';
import 'package:map/features/corporate/domain/services/exposure_activation_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

class JobPinActivationResult {
  const JobPinActivationResult({
    required this.success,
    this.updatedPoints,
    this.message,
    this.needsShop = false,
  });

  final bool success;
  final List<PushNotificationBasePoint>? updatedPoints;
  final String? message;
  final bool needsShop;
}

/// 일자리 알림핀 — 선택 핀별 노출 활성화
class JobPinActivationService {
  JobPinActivationService({
    PushWalletService? walletService,
    ExposureActivationService? exposureActivationService,
  })  : _walletService = walletService ?? PushWalletService(),
        _exposureActivationService =
            exposureActivationService ?? ExposureActivationService();

  final PushWalletService _walletService;
  final ExposureActivationService _exposureActivationService;

  Future<JobPinActivationResult> activateSelected({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required List<PushNotificationBasePoint> points,
    required Set<String> selectedPinIds,
    CorporatePaymentPreference paymentPreference =
        CorporatePaymentPreference.auto,
  }) async {
    if (selectedPinIds.isEmpty) {
      return const JobPinActivationResult(
        success: false,
        message: '노출할 일자리 알림핀을 선택해 주세요.',
      );
    }

    final targets = <int>[];
    for (var i = 0; i < points.length; i++) {
      if (!PushWalletCreditPolicy.isRecruitmentZoneIndex(i)) continue;
      if (selectedPinIds.contains(points[i].id) &&
          !points[i].isExposureLocked) {
        targets.add(i);
      }
    }
    if (targets.isEmpty) {
      return const JobPinActivationResult(
        success: false,
        message: '선택한 알림핀은 이미 노출 중입니다.',
      );
    }

    if (!context.mounted) {
      return const JobPinActivationResult(success: false);
    }

    final updated = List<PushNotificationBasePoint>.from(points);
    var pending = List<int>.from(targets);
    ExposureActivationCreditMode? preferredMode;

    // 1) 보유 이용권으로 먼저 소진
    while (pending.isNotEmpty) {
      if (!context.mounted) {
        return const JobPinActivationResult(success: false);
      }

      final wallet = await _walletService.loadWallet(profile);
      if (wallet.packageCredits <= 0) break;

      final mode = preferredMode ??
          await _exposureActivationService.pickCreditMode(
            context,
            wallet: wallet,
            title: '일자리 알림핀',
            subtitle: '선택한 알림핀 ${pending.length}곳을 구직자 지도에 노출합니다.',
          );
      if (!context.mounted) {
        return const JobPinActivationResult(success: false);
      }
      if (mode == null) break;

      preferredMode = mode;
      final consumed = await _exposureActivationService.consumeCredit(
        profile: profile,
        mode: mode,
      );
      if (!consumed.success) break;

      final index = pending.removeAt(0);
      updated[index] = ExposureSlotPolicy.lockActivation(updated[index]);
    }

    if (pending.isEmpty) {
      return JobPinActivationResult(
        success: true,
        updatedPoints: updated,
        message: '선택한 일자리 알림핀이 구직자 지도에 노출됩니다.',
      );
    }

    // 2) 남은 핀은 현금 결제 1회
    if (!context.mounted) {
      return const JobPinActivationResult(success: false);
    }

    final cashCount = pending.length;
    final bundle = PushPaymentBundle(
      radiusTier: PushRadiusTier.standard1km,
      pointTier: DesignatedPointTier.onePoint,
      spotCount: cashCount,
      isExtraPush: true,
      extraPushFeeKrw: cashCount * PushPackageCatalog.exposureUnitPriceKrw,
      paymentKind: JobPostPaymentRequestKind.jobPinExposure,
    );

    final result = await CorporatePaymentNavigationHelper().payOrRequest(
      context: context,
      bundle: bundle,
      kind: JobPostPaymentRequestKind.jobPinExposure,
      jobTitle: profile.companyName,
      preference: paymentPreference,
    );
    if (!context.mounted) {
      return const JobPinActivationResult(success: false);
    }

    if (result.isRequestSent) {
      return JobPinActivationResult(
        success: false,
        message: result.message ??
            '결제 담당자에게 요청을 보냈습니다. 승인 후 노출을 활성화해 주세요.',
        updatedPoints: updated,
      );
    }

    if (!result.isPaid) {
      return JobPinActivationResult(
        success: false,
        message: result.message ?? '결제가 취소되었습니다.',
        updatedPoints: updated,
      );
    }

    for (final index in pending) {
      updated[index] = ExposureSlotPolicy.lockActivation(updated[index]);
    }

    return JobPinActivationResult(
      success: true,
      updatedPoints: updated,
      message: '선택한 일자리 알림핀이 구직자 지도에 노출됩니다.',
    );
  }
}
