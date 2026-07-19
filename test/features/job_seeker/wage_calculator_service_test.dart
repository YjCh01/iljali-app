import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/wage_calculator_input.dart';
import 'package:map/features/job_seeker/domain/services/daily_labor_income_tax_calculator.dart';
import 'package:map/features/job_seeker/domain/services/minimum_wage_table.dart';
import 'package:map/features/job_seeker/domain/services/wage_calculator_service.dart';
import 'package:map/features/job_seeker/domain/services/weekly_holiday_allowance_calculator.dart';

void main() {
  group('MinimumWageTable', () {
    test('returns the known 2026 minimum wage', () {
      expect(MinimumWageTable.hourlyWage(2026), 10320);
    });

    test('falls back to latest year for years beyond the table', () {
      expect(MinimumWageTable.hourlyWage(2030), MinimumWageTable.hourlyWage(2026));
    });
  });

  group('DailyLaborIncomeTaxCalculator', () {
    test('is zero at or below the 150,000 threshold', () {
      expect(DailyLaborIncomeTaxCalculator.incomeTax(150000), 0);
      expect(DailyLaborIncomeTaxCalculator.incomeTax(100000), 0);
    });

    test('applies the exact 2.7% formula above the threshold', () {
      expect(DailyLaborIncomeTaxCalculator.incomeTax(200000), 1350);
      expect(DailyLaborIncomeTaxCalculator.localIncomeTax(1350), 135);
    });
  });

  group('WeeklyHolidayAllowanceCalculator', () {
    test('is zero under 15 hours a week', () {
      expect(WeeklyHolidayAllowanceCalculator.allowanceAmount(
        weeklyContractHours: 14,
        hourlyRate: 10000,
      ), 0);
    });

    test('gives 8 hours worth of pay at 40+ hours a week', () {
      expect(WeeklyHolidayAllowanceCalculator.allowanceAmount(
        weeklyContractHours: 40,
        hourlyRate: 10000,
      ), 80000);
    });

    test('prorates below 40 hours a week', () {
      expect(WeeklyHolidayAllowanceCalculator.allowanceAmount(
        weeklyContractHours: 20,
        hourlyRate: 10000,
      ), 40000);
    });
  });

  group('WageCalculatorService — daily mode', () {
    test('hourly basis at exactly minimum wage is not flagged as a violation', () {
      final result = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.daily,
        amount: 10320,
        year: 2026,
        dailyBasis: DailyWageBasis.hourly,
        hoursPerDay: 8,
      ));

      expect(result.hourlyRate, 10320);
      expect(result.basePay, 82560);
      expect(result.isBelowMinimumWage, isFalse);
      expect(result.employmentInsurance, 743);
      expect(result.incomeTax, 0);
      expect(result.netPay, 82560 - 743);
    });

    test('daily basis computes exact daily labor income tax and net pay', () {
      final result = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.daily,
        amount: 200000,
        year: 2026,
        dailyBasis: DailyWageBasis.daily,
        hoursPerDay: 8,
      ));

      expect(result.hourlyRate, 25000);
      expect(result.grossPay, 200000);
      expect(result.employmentInsurance, 1800);
      expect(result.incomeTax, 1350);
      expect(result.localIncomeTax, 135);
      expect(result.totalDeduction, 1800 + 1350 + 135);
      expect(result.netPay, 200000 - (1800 + 1350 + 135));
    });

    test('flags an hourly rate below minimum wage', () {
      final result = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.daily,
        amount: 9000,
        year: 2026,
        dailyBasis: DailyWageBasis.hourly,
        hoursPerDay: 8,
      ));

      expect(result.isBelowMinimumWage, isTrue);
    });

    test('applies overtime/night/holiday premiums only for 5+ employee workplaces', () {
      final withPremium = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.daily,
        amount: 10000,
        dailyBasis: DailyWageBasis.hourly,
        hoursPerDay: 8,
        overtimeHours: 2,
        hasFiveOrMoreEmployees: true,
      ));
      final withoutPremium = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.daily,
        amount: 10000,
        dailyBasis: DailyWageBasis.hourly,
        hoursPerDay: 8,
        overtimeHours: 2,
        hasFiveOrMoreEmployees: false,
      ));

      expect(withPremium.overtimePay, 30000);
      expect(withoutPremium.overtimePay, 20000);
    });

    test('does not deduct national pension or health insurance for daily workers', () {
      final result = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.daily,
        amount: 200000,
        dailyBasis: DailyWageBasis.daily,
      ));

      expect(result.nationalPension, 0);
      expect(result.healthInsurance, 0);
      expect(result.longTermCareInsurance, 0);
    });
  });

  group('WageCalculatorService — monthly mode', () {
    test('computes 4-major-insurance deductions and an estimated income tax', () {
      final result = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.monthly,
        amount: 2000000,
        year: 2026,
        weeklyContractHours: 40,
      ));

      expect(result.grossPay, 2000000);
      expect(result.nationalPension, 90000);
      expect(result.healthInsurance, 70900);
      expect(result.longTermCareInsurance, 9181);
      expect(result.employmentInsurance, 18000);
      expect(result.incomeTax, 30712);
      expect(result.localIncomeTax, 3071);
      expect(result.netPay, 2000000 - (90000 + 70900 + 9181 + 18000 + 30712 + 3071));
    });

    test('flags a full-time monthly salary below minimum wage', () {
      final result = WageCalculatorService.calculate(const WageCalculatorInput(
        mode: WageCalcMode.monthly,
        amount: 2000000,
        year: 2026,
        weeklyContractHours: 40,
      ));

      expect(result.isBelowMinimumWage, isTrue);
    });
  });
}
