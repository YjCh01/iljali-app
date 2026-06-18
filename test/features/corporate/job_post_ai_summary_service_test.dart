import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/services/job_post_ai_summary_service.dart';

void main() {
  test('generate summary includes key job fields', () async {
    final text = await JobPostAiSummaryService.generate(
      const JobPostAiSummaryInput(
        title: '물류 보조',
        workplaceLabel: '경기도 화성시 동탄대로 123',
        jobDescription: '입출고 및 분류 보조',
        workSchedule: '09:00-18:00 (주5일)',
        wageLabel: '12000',
        salaryPayType: SalaryPayType.hourly,
        workerCategory: WorkerCategory.daily,
        paymentScheduleLabel: '2026년 6월 10일',
      ),
    );

    expect(text, contains('물류 보조'));
    expect(text, contains('경기도 화성시'));
    expect(text, contains('입출고 및 분류 보조'));
    expect(text, contains('09:00-18:00'));
    expect(text, contains('12,000'));
  });
}
