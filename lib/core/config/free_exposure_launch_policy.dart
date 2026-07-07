import 'package:flutter/foundation.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/data/repositories/promo_exposure_quota_repository.dart';

/// 토스 PG 연동 전 — 일자리 알림핀·정류장 표시핀 노출을 무료로 허용하는 출시 프로모션.
///
/// 서버 `GET /health`의 `free_exposure_promo` 플래그를 따릅니다.
/// (기본: `TOSS_SECRET_KEY` 미설정 시 true)
abstract final class FreeExposureLaunchPolicy {
  static bool? _cached;
  static DateTime? _cachedAt;
  static const _cacheTtl = Duration(minutes: 5);

  /// 회사(companyKey)당 월 무료 노출 활성화 상한 — 핀·정류장·셔틀 오버레이 각 1회
  static const monthlyActivationCapPerCompany = 10;

  static const bannerTitle = '출시 기념 무료 노출';
  static const bannerBody =
      '결제 연동 전까지 일자리 알림핀·정류장 표시핀 노출이 무료입니다. '
      '회사당 월 $monthlyActivationCapPerCompany회까지 활성화할 수 있습니다. '
      '유료 전환 후 프로모션 노출은 종료되며 재결제가 필요합니다.';

  static const promoActivationMessage =
      '출시 기념 기간에 핀·정류장 노출이 무료로 적용되었습니다.';

  static String quotaExceededMessage(int remaining) =>
      remaining <= 0
          ? '이번 달 무료 노출 한도($monthlyActivationCapPerCompany회)를 모두 사용했습니다. '
              '다음 달에 다시 이용하거나 유료 결제를 이용해 주세요.'
          : '이번 달 무료 노출은 $remaining회 남았습니다. '
              '선택 수를 줄이거나 유료 결제를 이용해 주세요.';

  static Future<bool> isActive({IljariApiClient? client}) async {
    if (_cached != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cached!;
    }

    if (!EnvConfig.isComplianceApiEnabled) {
      _remember(_localFallbackActive);
      return _cached!;
    }

    try {
      final api = client ?? IljariApiClient();
      final health = await api.fetchHealth();
      _remember(health['free_exposure_promo'] == true);
      return _cached!;
    } catch (_) {
      _remember(_localFallbackActive);
      return _cached!;
    }
  }

  static Future<int> remainingActivationsThisMonth(String companyKey) async {
    if (companyKey.trim().isEmpty) return 0;
    if (!await isActive()) return 0;
    final repo = await PromoExposureQuotaRepository.create();
    return repo.remainingThisMonth(companyKey.trim());
  }

  static bool get _localFallbackActive =>
      !EnvConfig.isTossPaymentsConfigured || EnvConfig.qcMode;

  static void _remember(bool value) {
    _cached = value;
    _cachedAt = DateTime.now();
  }

  static void resetCache() {
    _cached = null;
    _cachedAt = null;
  }

  @visibleForTesting
  static void forceInactiveForTest() {
    _remember(false);
  }
}
