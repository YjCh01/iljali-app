import 'package:map/core/hiring/work_schedule_time.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';

/// 구직자 공고 상세 — 쉬운 급여 계산 결과
class EasySalaryEstimate {
  const EasySalaryEstimate({
    this.dailyKrw,
    this.weeklyKrw,
    this.monthlyKrw,
    this.hoursPerDay,
    this.payType = SalaryPayType.hourly,
    this.note,
  });

  final int? dailyKrw;
  final int? weeklyKrw;
  final int? monthlyKrw;
  final double? hoursPerDay;
  final SalaryPayType payType;
  final String? note;

  bool get hasEstimate =>
      dailyKrw != null || weeklyKrw != null || monthlyKrw != null;
}

/// 공고 급여 필드로 일·주·월 추정
abstract final class EasySalaryCalculator {
  static const defaultHoursPerDay = 8.0;
  static const weeklyWorkDays = 5;
  static const monthlyWorkDays = 22;

  static int parseKrw(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static double hoursPerDayFromSchedule(String workSchedule) {
    final start = WorkScheduleTime.parseStartClock(workSchedule);
    final end = WorkScheduleTime.parseEndClock(workSchedule);
    if (start == null || end == null) return defaultHoursPerDay;
    final startMinutes = start.$1 * 60 + start.$2;
    var endMinutes = end.$1 * 60 + end.$2;
    if (endMinutes <= startMinutes) endMinutes += 24 * 60;
    final hours = (endMinutes - startMinutes) / 60.0;
    return hours > 0 ? hours : defaultHoursPerDay;
  }

  static EasySalaryEstimate estimate(CorporateJobPost post) {
    final payType = parseSalaryPayType(post.hourlyWage);
    final baseAmount = parseKrw(post.hourlyWage);
    final dailyFromField = post.dailyWage != null ? parseKrw(post.dailyWage!) : 0;
    final hours = hoursPerDayFromSchedule(post.workSchedule);

    switch (payType) {
      case SalaryPayType.hourly:
        if (baseAmount <= 0) {
          return const EasySalaryEstimate(note: '시급 정보가 없어 계산할 수 없습니다.');
        }
        final daily = dailyFromField > 0
            ? dailyFromField
            : (baseAmount * hours).round();
        return EasySalaryEstimate(
          dailyKrw: daily,
          weeklyKrw: daily * weeklyWorkDays,
          monthlyKrw: daily * monthlyWorkDays,
          hoursPerDay: hours,
          payType: payType,
        );
      case SalaryPayType.daily:
        if (baseAmount <= 0 && dailyFromField <= 0) {
          return const EasySalaryEstimate(note: '일급 정보가 없어 계산할 수 없습니다.');
        }
        final daily = baseAmount > 0 ? baseAmount : dailyFromField;
        return EasySalaryEstimate(
          dailyKrw: daily,
          weeklyKrw: daily * weeklyWorkDays,
          monthlyKrw: daily * monthlyWorkDays,
          payType: payType,
        );
      case SalaryPayType.weekly:
        if (baseAmount <= 0) {
          return const EasySalaryEstimate(note: '주급 정보가 없어 계산할 수 없습니다.');
        }
        final daily = (baseAmount / weeklyWorkDays).round();
        return EasySalaryEstimate(
          dailyKrw: daily,
          weeklyKrw: baseAmount,
          monthlyKrw: (baseAmount / weeklyWorkDays * monthlyWorkDays).round(),
          payType: payType,
        );
      case SalaryPayType.monthly:
        if (baseAmount <= 0) {
          return const EasySalaryEstimate(note: '월급 정보가 없어 계산할 수 없습니다.');
        }
        final daily = (baseAmount / monthlyWorkDays).round();
        return EasySalaryEstimate(
          dailyKrw: daily,
          weeklyKrw: (baseAmount / monthlyWorkDays * weeklyWorkDays).round(),
          monthlyKrw: baseAmount,
          payType: payType,
        );
    }
  }

  static String formatKrw(int amount) {
    final text = amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '$text원';
  }
}
