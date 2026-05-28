import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/utils/daily_wage_calculator.dart';
import 'package:map/features/corporate/domain/utils/work_hours_calculator.dart';

void main() {
  group('WorkHoursCalculator', () {
    test('parses single daytime range with 1h break', () {
      expect(
        WorkHoursCalculator.dailyHoursFromSchedule('주 5일 · 09:00~18:00'),
        8,
      );
    });

    test('parses overnight range', () {
      expect(
        WorkHoursCalculator.dailyHoursFromSchedule('주 5일 · 22:00~06:00'),
        8,
      );
    });

    test('returns null when no time range', () {
      expect(
        WorkHoursCalculator.dailyHoursFromSchedule('주 5일 근무'),
        isNull,
      );
    });
  });

  group('DailyWageCalculator', () {
    test('calculates daily wage from hourly wage and schedule', () {
      expect(
        DailyWageCalculator.calculate(
          hourlyWage: '12500',
          workSchedule: '09:00~18:00',
        ),
        100000,
      );
    });

    test('formats daily wage with won suffix', () {
      expect(
        DailyWageCalculator.formattedDailyWage(
          hourlyWage: '10000',
          workSchedule: '09:00~18:00',
        ),
        '80,000원',
      );
    });
  });
}
