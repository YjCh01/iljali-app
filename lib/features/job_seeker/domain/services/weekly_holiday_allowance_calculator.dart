/// 주휴수당 — 1주 소정근로시간 15시간 이상 & 개근 시 발생.
abstract final class WeeklyHolidayAllowanceCalculator {
  static const eligibleThresholdHours = 15.0;
  static const standardWeeklyHours = 40.0;

  /// 주휴수당에 해당하는 시간(정규 근로자는 8시간 한도로 환산).
  static double allowanceHours(double weeklyContractHours) {
    if (weeklyContractHours < eligibleThresholdHours) return 0;
    final ratio = (weeklyContractHours / standardWeeklyHours).clamp(0.0, 1.0);
    return ratio * 8;
  }

  static int allowanceAmount({
    required double weeklyContractHours,
    required int hourlyRate,
  }) {
    return (allowanceHours(weeklyContractHours) * hourlyRate).round();
  }
}
