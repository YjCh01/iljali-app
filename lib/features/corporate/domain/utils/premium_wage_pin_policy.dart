import 'package:map/core/constants/labor_constants.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/utils/work_hours_calculator.dart';

/// 지도 하늘색 핀(premiumWage) — 시급·일급 등급 판정
abstract final class PremiumWagePinPolicy {
  /// 일급 기준선 = (최저시급 + 1,000원) × 1일 근무시간
  static int dailyThresholdForSchedule(String workSchedule) {
    final hours = WorkHoursCalculator.dailyHoursFromSchedule(workSchedule) ??
        LaborConstants.standardDailyPaidHours;
    return (LaborConstants.premiumHourlyThreshold * hours).round();
  }

  static double hoursPerDayForSchedule(String workSchedule) {
    return WorkHoursCalculator.dailyHoursFromSchedule(workSchedule) ??
        LaborConstants.standardDailyPaidHours;
  }

  static bool qualifies({
    required SalaryPayType payType,
    required String wageFieldText,
    required String workSchedule,
  }) {
    final amount = LaborConstants.parseWageFieldAmount(wageFieldText) ?? 0;
    if (amount <= 0) return false;

    return switch (payType) {
      SalaryPayType.hourly =>
        amount >= LaborConstants.premiumHourlyThreshold,
      SalaryPayType.daily =>
        amount >= dailyThresholdForSchedule(workSchedule),
      SalaryPayType.weekly ||
      SalaryPayType.monthly =>
        false,
    };
  }

  /// 저장된 급여 라벨(시급 10,320원 · 일급 150,000원 등)
  static bool qualifiesFromWageLabel({
    required String wageLabel,
    required String workSchedule,
  }) {
    final payType = parseSalaryPayType(wageLabel);
    final digits = salaryPayDigits(wageLabel);
    return qualifies(
      payType: payType,
      wageFieldText: digits,
      workSchedule: workSchedule,
    );
  }
}
