import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

final _postedAt = DateTime(2026, 5, 1);

void main() {
  group('SalaryPaymentSchedule', () {
    test('absoluteDate displayLabel and isComplete', () {
      final schedule = SalaryPaymentSchedule.absoluteDate(
        DateTime(2026, 5, 27),
      );
      expect(schedule.displayLabel, '2026년 5월 27일');
      expect(schedule.isComplete, isTrue);
    });

    test('monthlyRule displayLabel for 당월 and 익월', () {
      final sameMonth = SalaryPaymentSchedule.monthlyRule(
        monthOffset: SalaryPaymentMonthOffset.sameMonth,
        dayOfMonth: 25,
      );
      expect(sameMonth.displayLabel, '당월 25일');
      expect(sameMonth.isComplete, isTrue);

      final nextMonth = SalaryPaymentSchedule.monthlyRule(
        monthOffset: SalaryPaymentMonthOffset.nextMonth,
        dayOfMonth: 10,
      );
      expect(nextMonth.displayLabel, '익월 10일');
      expect(nextMonth.isComplete, isTrue);
    });

    test('monthlyRule isComplete rejects invalid day', () {
      final invalid = SalaryPaymentSchedule.monthlyRule(
        monthOffset: SalaryPaymentMonthOffset.sameMonth,
        dayOfMonth: 0,
      );
      expect(invalid.isComplete, isFalse);
    });
  });

  group('salaryPaymentScheduleFromPost', () {
    test('parses monthly rule from post fields', () {
      final post = CorporateJobPost(
        id: 'p1',
        title: 't',
        workerCategory: WorkerCategory.general,
        warehouseName: 'w',
        hourlyWage: '10,000원',
        workSchedule: '주5',
        summary: 's',
        paymentMonthOffset: SalaryPaymentMonthOffset.nextMonth,
        paymentDayOfMonth: 15,
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: _postedAt,
      );
      expect(post.paymentScheduleDisplayLabel, '익월 15일');
    });

    test('parses absolute date from paymentDate', () {
      final post = CorporateJobPost(
        id: 'p2',
        title: 't',
        workerCategory: WorkerCategory.daily,
        warehouseName: 'w',
        hourlyWage: '10,000원',
        workSchedule: '주5',
        summary: 's',
        paymentDate: DateTime(2026, 3, 1),
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: _postedAt,
      );
      expect(post.paymentScheduleDisplayLabel, '2026년 3월 1일');
      expect(post.effectiveWorkerCategory, WorkerCategory.daily);
    });

    test('old post without workerCategory infers daily from paymentDate', () {
      final post = CorporateJobPost(
        id: 'p3',
        title: 't',
        warehouseName: 'w',
        hourlyWage: '10,000원',
        workSchedule: '주5',
        summary: 's',
        paymentDate: DateTime(2026, 1, 20),
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: _postedAt,
      );
      expect(post.effectiveWorkerCategory, WorkerCategory.daily);
    });

    test('shortTerm parses absolute date and negotiable', () {
      final dated = CorporateJobPost(
        id: 'p4',
        title: 't',
        workerCategory: WorkerCategory.shortTerm,
        warehouseName: 'w',
        hourlyWage: '10,000원',
        workSchedule: '주5',
        summary: 's',
        paymentDate: DateTime(2026, 6, 15),
        status: CorporateJobPostStatus.recruiting,
        applicantCount: 0,
        postedAt: _postedAt,
      );
      expect(dated.paymentScheduleDisplayLabel, '2026년 6월 15일');

      final negotiable = dated.copyWith(
        paymentDate: null,
        paymentDateNegotiable: true,
      );
      expect(negotiable.paymentScheduleDisplayLabel, '협의');
    });
  });

  group('buildSalaryPaymentSchedule', () {
    test('workScheduleNegotiable makes daily payment negotiable', () {
      final schedule = buildSalaryPaymentSchedule(
        workerCategory: WorkerCategory.daily,
        workScheduleNegotiable: true,
        paymentDateNegotiable: false,
        workScheduleRaw: '',
      );
      expect(schedule, isA<SalaryPaymentNegotiable>());
      expect(schedule!.isComplete, isTrue);
    });

    test('daily without schedule remains incomplete', () {
      final schedule = buildSalaryPaymentSchedule(
        workerCategory: WorkerCategory.daily,
        workScheduleNegotiable: false,
        paymentDateNegotiable: false,
        workScheduleRaw: '',
      );
      expect(schedule, isNull);
    });

    test('negotiable schedule isComplete', () {
      expect(const SalaryPaymentSchedule.negotiable().isComplete, isTrue);
      expect(const SalaryPaymentSchedule.negotiable().displayLabel, '협의');
    });
  });
}
