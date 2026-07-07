import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/corporate/data/repositories/promo_exposure_quota_repository.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_source.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/exposure_slot_policy.dart';

/// 프로모션 무료 노출 — 월별 쿼터 검증·기록
class PromoExposureActivationHelper {
  PromoExposureActivationHelper({
    PromoExposureQuotaRepository? quotaRepository,
  }) : _quotaRepository = quotaRepository;

  PromoExposureQuotaRepository? _quotaRepository;

  Future<PromoExposureQuotaRepository> _quota() async =>
      _quotaRepository ??= await PromoExposureQuotaRepository.create();

  Future<PromoExposureConsumeResult> tryConsume({
    required String companyKey,
    required int count,
  }) async {
    if (count <= 0) {
      return const PromoExposureConsumeResult(success: false);
    }
    if (!await FreeExposureLaunchPolicy.isActive()) {
      return const PromoExposureConsumeResult(success: false);
    }

    final repo = await _quota();
    final remaining = await repo.remainingThisMonth(companyKey);
    if (remaining < count) {
      return PromoExposureConsumeResult(
        success: false,
        message: FreeExposureLaunchPolicy.quotaExceededMessage(remaining),
        remainingThisMonth: remaining,
      );
    }

    final consumed = await repo.tryConsume(companyKey, count);
    if (!consumed) {
      final after = await repo.remainingThisMonth(companyKey);
      return PromoExposureConsumeResult(
        success: false,
        message: FreeExposureLaunchPolicy.quotaExceededMessage(after),
        remainingThisMonth: after,
      );
    }

    final left = await repo.remainingThisMonth(companyKey);
    return PromoExposureConsumeResult(
      success: true,
      remainingThisMonth: left,
    );
  }

  PushNotificationBasePoint lockJobPinPromo(PushNotificationBasePoint point) {
    return ExposureSlotPolicy.lockActivation(
      point,
      activationSource: ExposureActivationSource.promo,
    );
  }

  CommuteRouteStop lockShuttleStopPromo(CommuteRouteStop stop) {
    return lockShuttleStop(stop, source: ExposureActivationSource.promo);
  }

  CommuteRouteStop lockShuttleStop(
    CommuteRouteStop stop, {
    required ExposureActivationSource source,
  }) {
    return stop.copyWith(
      exposureActivated: true,
      exposurePaidAt: DateTime.now(),
      exposureActivationSource: source,
    );
  }
}

class PromoExposureConsumeResult {
  const PromoExposureConsumeResult({
    required this.success,
    this.message,
    this.remainingThisMonth,
  });

  final bool success;
  final String? message;
  final int? remainingThisMonth;
}
