import 'package:map/core/hiring/permanent_commission_policy.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

/// 상시직 월급 기준 5.5% 수수료 계산
abstract final class PermanentCommissionCalculator {
  static double commissionRate({
    PremiumPartnershipTier? plan,
  }) {
    final tierRate =
        (plan ?? PartnershipPlanDefaults.activePlan)
            .permanentWorkerSuccessFeePercentMin /
        100;
    return tierRate > 0 ? tierRate : PermanentCommissionPolicy.commissionRate;
  }

  static int calculateAmount(
    int monthlySalaryKrw, {
    PremiumPartnershipTier? plan,
  }) {
    if (monthlySalaryKrw <= 0) return 0;
    return (monthlySalaryKrw * commissionRate(plan: plan)).round();
  }

  static String formatKrw(int amount) => PartnershipPlanFormat.krwSuffix(amount);
}
