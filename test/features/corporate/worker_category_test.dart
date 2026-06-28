import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';

void main() {
  group('WorkerCategory work period', () {
    test('regular uses start date only', () {
      expect(WorkerCategory.regular.usesFirstStartDateOnly, isTrue);
      expect(WorkerCategory.regular.usesWorkPeriodWithEndDate, isFalse);
    });

    test('contract requires start and end dates', () {
      expect(WorkerCategory.contract.usesFirstStartDateOnly, isFalse);
      expect(WorkerCategory.contract.usesWorkPeriodWithEndDate, isTrue);
    });

    test('daily uses date pick, not period range', () {
      expect(WorkerCategory.daily.usesWorkPeriodWithEndDate, isFalse);
    });
  });
}
