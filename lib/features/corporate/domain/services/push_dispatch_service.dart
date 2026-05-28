import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

/// 푸시 발송 전 지갑 소진 — 일 무료 → 보너스 → 패키지 (1km)
class PushDispatchService {
  PushDispatchService({PushWalletService? walletService})
      : _walletService = walletService ?? PushWalletService();

  final PushWalletService _walletService;

  Future<PushDispatchPrepareResult?> prepare({
    required BuildContext context,
    required CorporateMemberProfile profile,
  }) async {
    var current = profile;
    var consume = await _walletService.tryConsumePush(current);
    if (consume.success) {
      return PushDispatchPrepareResult(
        radiusTier: _radiusTierFromMeters(consume.radiusMeters!),
        paymentKrw: 0,
        source: consume.source!,
      );
    }

    if (!context.mounted) return null;
    final paymentResult =
        await Navigator.of(context).pushNamed<PaymentCompletionResult>(
      AppRoutes.corporateNotificationPayment,
      arguments: PushPaymentBundle.extraPush(
        feeKrw: PushPackageCatalog.singlePackagePriceKrw,
      ),
    );
    if (!context.mounted || paymentResult == null) return null;

    final single = PushPackageCatalog.findById(PushPackageCatalog.singlePackageId)!;
    current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    await _walletService.addPurchase(profile: current, offer: single);
    current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    consume = await _walletService.tryConsumePush(current);
    if (!consume.success) return null;

    return PushDispatchPrepareResult(
      radiusTier: _radiusTierFromMeters(consume.radiusMeters!),
      paymentKrw: PushPackageCatalog.singlePackagePriceKrw,
      source: consume.source!,
      paymentRecord: paymentResult.record,
    );
  }

  static PushRadiusTier _radiusTierFromMeters(int _) =>
      PushRadiusTier.standard1km;
}

class PushDispatchPrepareResult {
  const PushDispatchPrepareResult({
    required this.radiusTier,
    required this.paymentKrw,
    required this.source,
    this.paymentRecord,
  });

  final PushRadiusTier radiusTier;
  final int paymentKrw;
  final PushConsumeSource source;
  final JobPostPaymentRecord? paymentRecord;
}
