import 'package:map/features/job_seeker/domain/entities/wage_calculator_input.dart';
import 'package:map/features/job_seeker/domain/entities/wage_calculator_result.dart';
import 'package:map/features/job_seeker/domain/services/daily_labor_income_tax_calculator.dart';
import 'package:map/features/job_seeker/domain/services/four_major_insurance_calculator.dart';
import 'package:map/features/job_seeker/domain/services/minimum_wage_table.dart';
import 'package:map/features/job_seeker/domain/services/monthly_income_tax_estimator.dart';
import 'package:map/features/job_seeker/domain/services/weekly_holiday_allowance_calculator.dart';

/// 급여 실수령액 계산기 — 일용직/상용직 세전·세후 급여를 근로기준법·세법 산식으로
/// 계산한다(경쟁사 앱을 그대로 옮긴 것이 아니라 공공 데이터·법령 산식을 직접 구현).
abstract final class WageCalculatorService {
  static WageCalculatorResult calculate(WageCalculatorInput input) {
    return input.mode == WageCalcMode.daily
        ? _calculateDaily(input)
        : _calculateMonthly(input);
  }

  static WageCalculatorResult _calculateDaily(WageCalculatorInput input) {
    final hoursPerDay = input.hoursPerDay <= 0 ? 8 : input.hoursPerDay;
    final hourlyRate = input.dailyBasis == DailyWageBasis.hourly
        ? input.amount
        : (input.amount / hoursPerDay).round();
    final basePay = input.dailyBasis == DailyWageBasis.hourly
        ? (input.amount * hoursPerDay).round()
        : input.amount;

    final overtimePay = _overtimePay(hourlyRate, input);
    final nightPay = _nightPay(hourlyRate, input);
    final holidayPay = _holidayPay(hourlyRate, input);
    final weeklyHolidayAllowance = input.includeWeeklyHolidayAllowance
        ? WeeklyHolidayAllowanceCalculator.allowanceAmount(
            weeklyContractHours: input.weeklyContractHours,
            hourlyRate: hourlyRate,
          )
        : 0;

    final grossPay =
        basePay + overtimePay + nightPay + holidayPay + weeklyHolidayAllowance;

    // 일용직은 원칙적으로 국민연금·건강보험 적용 제외, 고용보험만 부담.
    final employmentInsurance =
        FourMajorInsuranceCalculator.employmentInsurance(grossPay);
    final incomeTax = DailyLaborIncomeTaxCalculator.incomeTax(grossPay);
    final localIncomeTax =
        DailyLaborIncomeTaxCalculator.localIncomeTax(incomeTax);

    final totalDeduction = employmentInsurance + incomeTax + localIncomeTax;
    final minimumWage =
        MinimumWageTable.hourlyWage(input.year ?? MinimumWageTable.latestYear);

    return WageCalculatorResult(
      mode: WageCalcMode.daily,
      hourlyRate: hourlyRate,
      minimumWage: minimumWage,
      isBelowMinimumWage: hourlyRate < minimumWage,
      basePay: basePay,
      overtimePay: overtimePay,
      nightPay: nightPay,
      holidayPay: holidayPay,
      weeklyHolidayAllowance: weeklyHolidayAllowance,
      grossPay: grossPay,
      nationalPension: 0,
      healthInsurance: 0,
      longTermCareInsurance: 0,
      employmentInsurance: employmentInsurance,
      incomeTax: incomeTax,
      localIncomeTax: localIncomeTax,
      totalDeduction: totalDeduction,
      netPay: grossPay - totalDeduction,
    );
  }

  static WageCalculatorResult _calculateMonthly(WageCalculatorInput input) {
    final weeklyHolidayHours = WeeklyHolidayAllowanceCalculator.allowanceHours(
      input.weeklyContractHours,
    );
    final monthlyHours =
        (input.weeklyContractHours + weeklyHolidayHours) * (365.0 / 7 / 12);
    final hourlyRate =
        monthlyHours <= 0 ? 0 : (input.amount / monthlyHours).round();

    final overtimePay = _overtimePay(hourlyRate, input);
    final nightPay = _nightPay(hourlyRate, input);
    final holidayPay = _holidayPay(hourlyRate, input);

    // 월급에는 주휴수당이 이미 포함되어 있다고 보아 별도 가산하지 않음.
    final grossPay = input.amount + overtimePay + nightPay + holidayPay;

    final nationalPension =
        FourMajorInsuranceCalculator.nationalPension(grossPay);
    final healthInsurance =
        FourMajorInsuranceCalculator.healthInsurance(grossPay);
    final longTermCareInsurance =
        FourMajorInsuranceCalculator.longTermCareInsurance(healthInsurance);
    final employmentInsurance =
        FourMajorInsuranceCalculator.employmentInsurance(grossPay);
    final incomeTax = MonthlyIncomeTaxEstimator.estimateMonthlyIncomeTax(
      monthlyGrossPay: grossPay,
      dependents: input.dependents,
    );
    final localIncomeTax = MonthlyIncomeTaxEstimator.localIncomeTax(incomeTax);

    final totalDeduction = nationalPension +
        healthInsurance +
        longTermCareInsurance +
        employmentInsurance +
        incomeTax +
        localIncomeTax;
    final minimumWage =
        MinimumWageTable.hourlyWage(input.year ?? MinimumWageTable.latestYear);

    return WageCalculatorResult(
      mode: WageCalcMode.monthly,
      hourlyRate: hourlyRate,
      minimumWage: minimumWage,
      isBelowMinimumWage: hourlyRate < minimumWage,
      basePay: input.amount,
      overtimePay: overtimePay,
      nightPay: nightPay,
      holidayPay: holidayPay,
      weeklyHolidayAllowance: 0,
      grossPay: grossPay,
      nationalPension: nationalPension,
      healthInsurance: healthInsurance,
      longTermCareInsurance: longTermCareInsurance,
      employmentInsurance: employmentInsurance,
      incomeTax: incomeTax,
      localIncomeTax: localIncomeTax,
      totalDeduction: totalDeduction,
      netPay: grossPay - totalDeduction,
    );
  }

  static int _overtimePay(int hourlyRate, WageCalculatorInput input) {
    if (input.overtimeHours <= 0) return 0;
    final multiplier = input.hasFiveOrMoreEmployees ? 1.5 : 1.0;
    return (hourlyRate * multiplier * input.overtimeHours).round();
  }

  static int _nightPay(int hourlyRate, WageCalculatorInput input) {
    if (input.nightHours <= 0 || !input.hasFiveOrMoreEmployees) return 0;
    return (hourlyRate * 0.5 * input.nightHours).round();
  }

  static int _holidayPay(int hourlyRate, WageCalculatorInput input) {
    if (input.holidayHours <= 0) return 0;
    if (!input.hasFiveOrMoreEmployees) {
      return (hourlyRate * input.holidayHours).round();
    }
    final normalHours =
        input.holidayHours > 8 ? 8 : input.holidayHours;
    final extraHours = input.holidayHours > 8 ? input.holidayHours - 8 : 0.0;
    return (hourlyRate * 1.5 * normalHours + hourlyRate * 2.0 * extraHours)
        .round();
  }
}
