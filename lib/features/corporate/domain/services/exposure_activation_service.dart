import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';
import 'package:map/features/corporate/domain/entities/push_dispatch_target.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_dispatch_service.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';
import 'package:map/features/corporate/presentation/widgets/exposure_activation_mode_sheet.dart';

/// 알림핀·정류장 노출 활성화 + (옵션) 번들 PUSH 발송
class ExposureActivationService {
  ExposureActivationService({PushWalletService? walletService})
      : _walletService = walletService ?? PushWalletService();

  final PushWalletService _walletService;

  Future<ExposureActivationCreditMode?> pickCreditMode(
    BuildContext context, {
    required EmployerPushWallet wallet,
    String title = '이용권 선택',
    String? subtitle,
  }) {
    return showExposureActivationModeSheet(
      context,
      wallet: wallet,
      title: title,
      subtitle: subtitle,
    );
  }

  Future<PushConsumeResult> consumeCredit({
    required CorporateMemberProfile profile,
    required ExposureActivationCreditMode mode,
  }) {
    return switch (mode) {
      ExposureActivationCreditMode.exposureOnly =>
        _walletService.tryConsumeRecruitmentCredit(profile),
      ExposureActivationCreditMode.exposureWithPush =>
        _walletService.tryConsumeExposurePushBundle(profile),
    };
  }

  PushDispatchTarget targetFromPinPoint({
    required PushNotificationBasePoint point,
    required int index,
  }) {
    if (index == 0) {
      return PushDispatchTarget(
        id: 'workplace',
        kind: PushDispatchTargetKind.workplace,
        title: '근무지',
        subtitle: point.addressLabel.isNotEmpty
            ? point.addressLabel
            : PushDispatchTargetKind.workplace.iconHint,
        coordinate: point.coordinate,
        radiusMeters: point.radiusMeters > 0
            ? point.radiusMeters
            : PushPackageCatalog.freePushRadiusM,
        basePointId: point.id,
      );
    }

    return PushDispatchTarget(
      id: 'pin_${point.id}',
      kind: PushDispatchTargetKind.notificationPin,
      title: point.addressLabel.isNotEmpty
          ? point.addressLabel
          : ExposurePointLabels.title(index),
      subtitle: PushDispatchTargetKind.notificationPin.iconHint,
      coordinate: point.coordinate,
      radiusMeters: point.radiusMeters > 0
          ? point.radiusMeters
          : PushPackageCatalog.packagePushRadiusM,
      basePointId: point.id,
    );
  }

  /// 노출+PUSH 번들에 포함된 1회 PUSH — 추가 결제·PUSH권 없음
  Future<bool> sendIncludedPush({
    required BuildContext context,
    required CorporateMemberProfile profile,
    required CorporateJobPost post,
    required PushDispatchTarget target,
  }) async {
    if (!context.mounted) return false;

    final prepared = await PushDispatchService().prepareTargetedDispatch(
      context: context,
      profile: profile,
      post: post,
      target: target,
      paymentMode: PushTargetPaymentMode.comboIncluded,
    );
    if (!context.mounted || prepared == null) return false;

    await Navigator.of(context).pushNamed<bool>(
      AppRoutes.corporatePushDispatch,
      arguments: PushDispatchArgs(
        radiusTier: prepared.radiusTier,
        recruitmentSlotCount: 1,
        jobPostId: post.id,
        jobTitle: post.title,
        companyName: profile.companyName,
        targetLabel: target.displayLine,
        targetKind: target.kind,
        reachSeed: target.coordinate.latitude.hashCode ^
            target.coordinate.longitude.hashCode,
      ),
    );
    return true;
  }
}
