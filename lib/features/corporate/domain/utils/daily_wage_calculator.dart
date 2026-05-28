import 'package:map/features/corporate/domain/utils/work_hours_calculator.dart';

/// 시급 × 일 근무시간 → 일급
abstract final class DailyWageCalculator {
  static int? calculate({
    required String hourlyWage,
    required String workSchedule,
  }) {
    final hourly = int.tryParse(
      hourlyWage.replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final hours = WorkHoursCalculator.dailyHoursFromSchedule(workSchedule);
    if (hourly == null || hourly <= 0 || hours == null || hours <= 0) {
      return null;
    }
    return (hourly * hours).round();
  }

  static String? formattedDailyWage({
    required String hourlyWage,
    required String workSchedule,
  }) {
    final amount = calculate(
      hourlyWage: hourlyWage,
      workSchedule: workSchedule,
    );
    if (amount == null) return null;
    return '${_formatNumber(amount)}원';
  }

  static String _formatNumber(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]},',
        );
  }
}
