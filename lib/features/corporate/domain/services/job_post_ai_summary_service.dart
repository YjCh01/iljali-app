import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

/// AI 공고 요약 생성 입력
class JobPostAiSummaryInput {
  const JobPostAiSummaryInput({
    required this.title,
    this.workplaceLabel,
    this.jobDescription = '',
    required this.workSchedule,
    required this.wageLabel,
    required this.salaryPayType,
    required this.workerCategory,
    this.paymentScheduleLabel,
  });

  final String title;
  final String? workplaceLabel;
  final String jobDescription;
  final String workSchedule;
  final String wageLabel;
  final SalaryPayType salaryPayType;
  final WorkerCategory workerCategory;
  final String? paymentScheduleLabel;

  bool get hasMinimumFields =>
      title.trim().isNotEmpty &&
      workplaceLabel != null &&
      workplaceLabel!.trim().isNotEmpty &&
      workSchedule.trim().isNotEmpty &&
      wageLabel.trim().isNotEmpty;
}

/// 입력된 공고 항목을 바탕으로 구직자용 요약 문구 생성 (로컬 MVP)
abstract final class JobPostAiSummaryService {
  static Future<String> generate(JobPostAiSummaryInput input) async {
    await Future<void>.delayed(const Duration(milliseconds: 350));

    final title = input.title.trim();
    final workplace = input.workplaceLabel!.trim();
    final schedule = input.workSchedule.trim();
    final wage = input.salaryPayType.formatAmount(input.wageLabel.trim());
    final category = input.workerCategory.label;
    final payment = input.paymentScheduleLabel ?? '협의';
    final duty = _dutyLine(input.jobDescription.trim(), title);

    return [
      '「$title」 채용 안내',
      '',
      '근무지: $workplace',
      '업무: $duty',
      '근무 일정: $schedule',
      '급여: $wage (${input.salaryPayType.label})',
      '급여 지급: $payment',
      '고용 형태: $category',
      '',
      '성실하고 책임감 있게 근무해 주실 분을 모십니다.',
      '지원 전 궁금한 점은 채팅으로 편하게 문의해 주세요.',
    ].join('\n');
  }

  static String _dutyLine(String description, String title) {
    if (description.isNotEmpty) {
      final firstLine = description.split('\n').first.trim();
      if (firstLine.length <= 80) return firstLine;
      return '${firstLine.substring(0, 77)}…';
    }
    return '$title 관련 현장 업무';
  }

  static String? paymentLabel({
    required WorkerCategory workerCategory,
    DateTime? paymentDate,
    SalaryPaymentMonthOffset? monthOffset,
    int? dayOfMonth,
    bool paymentDateNegotiable = false,
  }) {
    if (paymentDateNegotiable &&
        (workerCategory.usesAbsolutePaymentDate ||
            workerCategory.usesCalendarPaymentDate)) {
      return const SalaryPaymentSchedule.negotiable().displayLabel;
    }
    if (workerCategory.usesAbsolutePaymentDate ||
        workerCategory.usesCalendarPaymentDate) {
      if (paymentDate == null) return null;
      return SalaryPaymentSchedule.absoluteDate(paymentDate).displayLabel;
    }
    if (monthOffset == null || dayOfMonth == null) return null;
    return SalaryPaymentSchedule.monthlyRule(
      monthOffset: monthOffset,
      dayOfMonth: dayOfMonth,
    ).displayLabel;
  }
}
