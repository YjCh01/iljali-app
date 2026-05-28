import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

/// 일용직(출근 확인) · 상시직(재직 확인) 중개 수수료
abstract final class CommissionCalculator {
  static PremiumPartnershipTier get _plan => PartnershipPlanDefaults.activePlan;

  /// 일용직 — 출근 확인 시 고정 수수료 (원)
  static int dailyWorkerFee({
    PremiumPartnershipTier? plan,
  }) =>
      (plan ?? _plan).dailyWorkerSuccessFeeKrwMin;

  /// 상시직 — 재직 확인 후 월급 대비 수수료 (%)
  static double permanentWorkerFeePercent({
    PremiumPartnershipTier? plan,
  }) =>
      (plan ?? _plan).permanentWorkerSuccessFeePercentMin;

  /// 상시직 수수료 금액 추정 (시급 × 8시간 기준)
  static int estimatePermanentFromHourlyWage(
    String hourlyWageText, {
    PremiumPartnershipTier? plan,
  }) {
    final tier = plan ?? _plan;
    final digits = hourlyWageText.replaceAll(RegExp(r'[^0-9]'), '');
    final hourly = int.tryParse(digits);
    if (hourly == null || hourly <= 0) {
      return dailyWorkerFee(plan: tier);
    }
    final estimatedDaily = hourly * 8;
    return (estimatedDaily * permanentWorkerFeePercent(plan: tier) / 100)
        .round();
  }

  static int defaultKrw({PremiumPartnershipTier? plan}) =>
      dailyWorkerFee(plan: plan);

  static String formatKrw(int amount) =>
      PartnershipPlanFormat.krwSuffix(amount);

  static String feeDescription({
    PremiumPartnershipTier? plan,
    bool isPermanentWorker = false,
  }) {
    final tier = plan ?? _plan;
    if (isPermanentWorker) {
      return '상시직 재직 확인 시 월급 ${tier.permanentWorkerSuccessFeeLabel} (30일 주기)';
    }
    return '일용직 출근 확인 시 ${tier.dailyWorkerSuccessFeeLabel}';
  }
}
