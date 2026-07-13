import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/utils/daily_worker_policy.dart';

/// 급여 지급 월 기준 (당월 · 익월)
enum SalaryPaymentMonthOffset {
  sameMonth,
  nextMonth,
}

extension SalaryPaymentMonthOffsetX on SalaryPaymentMonthOffset {
  String get label => switch (this) {
        SalaryPaymentMonthOffset.sameMonth => '당월',
        SalaryPaymentMonthOffset.nextMonth => '익월',
      };
}

/// 급여지급일 — 일용직 절대일 · 일반/계약 당월·익월 N일
sealed class SalaryPaymentSchedule {
  const SalaryPaymentSchedule();

  const factory SalaryPaymentSchedule.absoluteDate(DateTime date) =
      SalaryPaymentAbsoluteDate;

  /// 일용직 — 선택된 각 근무일의 다음 날
  const factory SalaryPaymentSchedule.dailyPerWorkDay(
    List<DateTime> dates,
  ) = SalaryPaymentDailyPerWorkDay;

  const factory SalaryPaymentSchedule.monthlyRule({
    required SalaryPaymentMonthOffset monthOffset,
    required int dayOfMonth,
  }) = SalaryPaymentMonthlyRule;

  /// 구인·구직자 간 협의 (일용직)
  const factory SalaryPaymentSchedule.negotiable() = SalaryPaymentNegotiable;
}

final class SalaryPaymentAbsoluteDate extends SalaryPaymentSchedule {
  const SalaryPaymentAbsoluteDate(this.date);

  final DateTime date;
}

final class SalaryPaymentDailyPerWorkDay extends SalaryPaymentSchedule {
  const SalaryPaymentDailyPerWorkDay(this.dates);

  final List<DateTime> dates;
}

final class SalaryPaymentMonthlyRule extends SalaryPaymentSchedule {
  const SalaryPaymentMonthlyRule({
    required this.monthOffset,
    required this.dayOfMonth,
  });

  final SalaryPaymentMonthOffset monthOffset;
  final int dayOfMonth;
}

final class SalaryPaymentNegotiable extends SalaryPaymentSchedule {
  const SalaryPaymentNegotiable();
}

extension SalaryPaymentScheduleX on SalaryPaymentSchedule {
  bool get isComplete => switch (this) {
        SalaryPaymentAbsoluteDate() => true,
        SalaryPaymentDailyPerWorkDay(:final dates) => dates.isNotEmpty,
        SalaryPaymentMonthlyRule(:final dayOfMonth) =>
          dayOfMonth >= 1 && dayOfMonth <= 31,
        SalaryPaymentNegotiable() => true,
      };

  String get displayLabel => switch (this) {
        SalaryPaymentAbsoluteDate(:final date) =>
          '${date.year}년 ${date.month}월 ${date.day}일',
        SalaryPaymentDailyPerWorkDay(:final dates) => dates
            .map((date) => '${date.year}년 ${date.month}월 ${date.day}일')
            .join('\n'),
        SalaryPaymentMonthlyRule(:final monthOffset, :final dayOfMonth) =>
          '${monthOffset.label} $dayOfMonth일',
        SalaryPaymentNegotiable() => '협의',
      };
}

SalaryPaymentSchedule? salaryPaymentScheduleFromPost(CorporateJobPost post) {
  if (post.paymentDateNegotiable) {
    return const SalaryPaymentSchedule.negotiable();
  }
  if (post.paymentMonthOffset != null && post.paymentDayOfMonth != null) {
    return SalaryPaymentSchedule.monthlyRule(
      monthOffset: post.paymentMonthOffset!,
      dayOfMonth: post.paymentDayOfMonth!,
    );
  }
  if (post.effectiveWorkerCategory == WorkerCategory.daily) {
    final dailyDates =
        DailyWorkerPolicy.paymentDatesFromWorkSchedule(post.workSchedule);
    if (dailyDates.isNotEmpty) {
      return SalaryPaymentSchedule.dailyPerWorkDay(dailyDates);
    }
  }
  if (post.paymentDate != null) {
    return SalaryPaymentSchedule.absoluteDate(post.paymentDate!);
  }
  return null;
}

/// 작성/수정 폼 공통 — 근무일정 협의 시 일용·단기 급여일도 협의.
SalaryPaymentSchedule? buildSalaryPaymentSchedule({
  required WorkerCategory workerCategory,
  required bool workScheduleNegotiable,
  required bool paymentDateNegotiable,
  required String workScheduleRaw,
  DateTime? paymentDate,
  SalaryPaymentMonthOffset? paymentMonthOffset,
  int? paymentDayOfMonth,
}) {
  final dateBased = workerCategory.usesAbsolutePaymentDate ||
      workerCategory.usesCalendarPaymentDate;
  if (dateBased && (workScheduleNegotiable || paymentDateNegotiable)) {
    return const SalaryPaymentSchedule.negotiable();
  }
  if (workerCategory.usesAbsolutePaymentDate) {
    final dates =
        DailyWorkerPolicy.paymentDatesFromWorkSchedule(workScheduleRaw);
    if (dates.isEmpty) return null;
    return SalaryPaymentSchedule.dailyPerWorkDay(dates);
  }
  if (workerCategory.usesCalendarPaymentDate) {
    if (paymentDate == null) return null;
    return SalaryPaymentSchedule.absoluteDate(paymentDate);
  }
  if (workerCategory.usesMonthlyPaymentDate) {
    if (paymentMonthOffset == null || paymentDayOfMonth == null) {
      return null;
    }
    return SalaryPaymentSchedule.monthlyRule(
      monthOffset: paymentMonthOffset,
      dayOfMonth: paymentDayOfMonth,
    );
  }
  return null;
}
