/// 급여 계산기 계산 기준 — 일용직(일급/시급) vs 상용직(월급).
enum WageCalcMode { daily, monthly }

/// 일용직 모드에서 기준 금액을 시급으로 줄지 일급으로 줄지.
enum DailyWageBasis { hourly, daily }

class WageCalculatorInput {
  const WageCalculatorInput({
    required this.mode,
    required this.amount,
    this.year,
    this.dailyBasis = DailyWageBasis.hourly,
    this.hoursPerDay = 8,
    this.overtimeHours = 0,
    this.nightHours = 0,
    this.holidayHours = 0,
    this.hasFiveOrMoreEmployees = true,
    this.includeWeeklyHolidayAllowance = false,
    this.weeklyContractHours = 40,
    this.dependents = 1,
  });

  final WageCalcMode mode;

  /// 일용직: 시급 또는 일급(dailyBasis에 따라 다름) / 상용직: 월급(세전).
  final int amount;

  final int? year;

  final DailyWageBasis dailyBasis;

  /// 하루 소정근로시간(일용직 모드에서 시급→일급 환산 및 최저임금 검증에 사용).
  final double hoursPerDay;

  /// 연장근로시간(가산수당 적용 대상).
  final double overtimeHours;

  /// 야간근로시간(22시~06시, 가산수당 적용 대상).
  final double nightHours;

  /// 휴일근로시간(가산수당 적용 대상).
  final double holidayHours;

  /// 5인 이상 사업장 여부 — 연장/야간/휴일 가산수당은 5인 미만 사업장엔 적용되지 않음.
  final bool hasFiveOrMoreEmployees;

  /// 일용직 모드에서 매주 반복 근무로 주휴수당 요건을 충족하는지.
  final bool includeWeeklyHolidayAllowance;

  /// 주휴수당 계산에 쓰이는 주 소정근로시간(일용직 반복근무 시).
  final double weeklyContractHours;

  /// 상용직 모드 소득세 추정에 쓰이는 부양가족 수(본인 포함).
  final int dependents;
}
