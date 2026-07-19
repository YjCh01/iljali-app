import 'package:map/features/job_seeker/domain/entities/wage_calculator_input.dart';

class WageCalculatorResult {
  const WageCalculatorResult({
    required this.mode,
    required this.hourlyRate,
    required this.minimumWage,
    required this.isBelowMinimumWage,
    required this.basePay,
    required this.overtimePay,
    required this.nightPay,
    required this.holidayPay,
    required this.weeklyHolidayAllowance,
    required this.grossPay,
    required this.nationalPension,
    required this.healthInsurance,
    required this.longTermCareInsurance,
    required this.employmentInsurance,
    required this.incomeTax,
    required this.localIncomeTax,
    required this.totalDeduction,
    required this.netPay,
  });

  final WageCalcMode mode;

  /// 환산 통상시급.
  final int hourlyRate;

  final int minimumWage;

  final bool isBelowMinimumWage;

  final int basePay;

  final int overtimePay;

  final int nightPay;

  final int holidayPay;

  final int weeklyHolidayAllowance;

  /// 세전 합계.
  final int grossPay;

  final int nationalPension;

  final int healthInsurance;

  final int longTermCareInsurance;

  final int employmentInsurance;

  final int incomeTax;

  final int localIncomeTax;

  final int totalDeduction;

  /// 실수령액.
  final int netPay;
}
