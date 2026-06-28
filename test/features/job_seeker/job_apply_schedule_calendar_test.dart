import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/selected_shift_dates.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_calendar_utils.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

void main() {
  group('SelectedShiftDates', () {
    test('encodes and decodes sorted unique dates', () {
      final encoded = SelectedShiftDates.encode([
        DateTime(2026, 7, 3),
        DateTime(2026, 6, 28),
        DateTime(2026, 6, 28),
      ]);
      expect(encoded, '2026-06-28,2026-07-03');
      expect(
        SelectedShiftDates.decode(encoded),
        [DateTime(2026, 6, 28), DateTime(2026, 7, 3)],
      );
    });
  });

  group('WorkScheduleCalendarX', () {
    test('daily pick lists future employer work days only', () {
      final spec = WorkScheduleSpec(
        mode: WorkScheduleMode.dailyPick,
        selectedWorkDates: {
          DateTime(2020, 1, 1),
          DateTime(2030, 6, 28),
          DateTime(2030, 6, 29),
        },
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2030, 6, 29),
      );

      final days = spec.seekerSelectableWorkDays();
      expect(days, isNot(contains(DateTime(2020, 1, 1))));
      expect(days, contains(DateTime(2030, 6, 28)));
      expect(days, contains(DateTime(2030, 6, 29)));
    });

    test('parses daily schedule for calendar display', () {
      const raw =
          '일용 · 2026-06-28,2026-06-29,2026-06-30 · 09:00~18:00 · 근무3일';
      final spec = WorkScheduleCodec.tryParse(raw)!;
      expect(spec.mode, WorkScheduleMode.dailyPick);
      expect(spec.selectedWorkDates.length, 3);
      expect(spec.monthsToShow(), isNotEmpty);
    });
  });
}
