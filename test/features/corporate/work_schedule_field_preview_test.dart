import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/presentation/widgets/work_schedule_field_preview.dart';

void main() {
  group('WorkSchedulePreviewFormatter', () {
    test('daily pick splits into headline and date chips', () {
      final model = WorkSchedulePreviewFormatter.fromRaw(
        '일용 · 2026-05-13,2026-05-14,2026-05-15,2026-05-20,2026-05-21,2026-05-22 · 09:00~18:00 · 근무6일',
      );
      expect(model, isNotNull);
      expect(model!.headline, contains('6일'));
      expect(model.chips.length, 6);
      expect(model.needsExpand, isFalse);
    });

    test('many daily dates need expand', () {
      final dates = List.generate(
        8,
        (i) => '2026-05-${(13 + i).toString().padLeft(2, '0')}',
      ).join(',');
      final model = WorkSchedulePreviewFormatter.fromRaw(
        '일용 · $dates · 09:00~18:00 · 근무8일',
      );
      expect(model!.chips.length, 8);
      expect(model.needsExpand, isTrue);
    });

    test('varied daily hours show time on each chip', () {
      final model = WorkSchedulePreviewFormatter.fromRaw(
        '일용 · 2026-06-14@09:00~18:00,2026-06-15@09:00~17:00 · 근무2일',
      );
      expect(model, isNotNull);
      expect(model!.headline, contains('날짜별'));
      expect(model.chips.length, 2);
      expect(model.chips.first, contains('09:00~18:00'));
      expect(model.chips.last, contains('09:00~17:00'));
    });

    test('regular fixed weekdays preview without end date', () {
      final model = WorkSchedulePreviewFormatter.fromRaw(
        '정규·주5일(월화수목금) · 2026-06-01 · 09:00~18:00',
      );
      expect(model, isNotNull);
      expect(model!.headline, contains('정규'));
      expect(model.lines.first, contains('첫 근무'));
      expect(model.lines.first, isNot(contains('~')));
    });

    test('regular negotiable-only preview without start date', () {
      final model = WorkSchedulePreviewFormatter.fromRaw(
        '정규·주5일(월화수목금) · 09:00~18:00',
      );
      expect(model, isNotNull);
      expect(model!.lines.first, contains('협의'));
    });
  });
}
