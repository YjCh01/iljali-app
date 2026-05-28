import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

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

  const factory SalaryPaymentSchedule.monthlyRule({
    required SalaryPaymentMonthOffset monthOffset,
    required int dayOfMonth,
  }) = SalaryPaymentMonthlyRule;
}

final class SalaryPaymentAbsoluteDate extends SalaryPaymentSchedule {
  const SalaryPaymentAbsoluteDate(this.date);

  final DateTime date;
}

final class SalaryPaymentMonthlyRule extends SalaryPaymentSchedule {
  const SalaryPaymentMonthlyRule({
    required this.monthOffset,
    required this.dayOfMonth,
  });

  final SalaryPaymentMonthOffset monthOffset;
  final int dayOfMonth;
}

extension SalaryPaymentScheduleX on SalaryPaymentSchedule {
  bool get isComplete => switch (this) {
        SalaryPaymentAbsoluteDate(:final date) => true,
        SalaryPaymentMonthlyRule(:final dayOfMonth) =>
          dayOfMonth >= 1 && dayOfMonth <= 31,
      };

  String get displayLabel => switch (this) {
        SalaryPaymentAbsoluteDate(:final date) =>
          '${date.year}년 ${date.month}월 ${date.day}일',
        SalaryPaymentMonthlyRule(:final monthOffset, :final dayOfMonth) =>
          '${monthOffset.label} $dayOfMonth일',
      };
}

SalaryPaymentSchedule? salaryPaymentScheduleFromPost(CorporateJobPost post) {
  if (post.paymentMonthOffset != null && post.paymentDayOfMonth != null) {
    return SalaryPaymentSchedule.monthlyRule(
      monthOffset: post.paymentMonthOffset!,
      dayOfMonth: post.paymentDayOfMonth!,
    );
  }
  if (post.paymentDate != null) {
    return SalaryPaymentSchedule.absoluteDate(post.paymentDate!);
  }
  return null;
}
