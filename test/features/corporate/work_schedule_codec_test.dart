import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';
import 'package:map/features/corporate/presentation/widgets/work_schedule_selector_field.dart';

void main() {
  group('WorkScheduleCodec', () {
    test('round-trips fixed weekdays', () {
      final encoded = WorkScheduleCodec.encode(
        WorkScheduleSpec(
          mode: WorkScheduleMode.fixedWeekdays,
          startDate: DateTime(2026, 5, 7),
          endDate: DateTime(2026, 5, 23),
          weekdays: {0, 1, 2, 3, 4},
          dayStart: TimeOfDay(hour: 9, minute: 0),
          dayEnd: TimeOfDay(hour: 18, minute: 0),
        ),
      );
      expect(encoded, contains('주5일(월화수목금)'));
      expect(encoded, contains('2026-05-07~2026-05-23'));
      expect(encoded, contains('09:00~18:00'));

      final parsed = WorkScheduleCodec.tryParse(encoded)!;
      expect(parsed.mode, WorkScheduleMode.fixedWeekdays);
      expect(parsed.weekdays, {0, 1, 2, 3, 4});
      expect(parsed.countWorkDays(), 12);
    });

    test('round-trips rotating 3조2교대', () {
      final encoded = WorkScheduleCodec.encode(
        WorkScheduleSpec(
          mode: WorkScheduleMode.rotatingShift,
          startDate: DateTime(2026, 5, 7),
          endDate: DateTime(2026, 5, 20),
          rotatingPresetId: RotatingShiftPreset.threeTeamTwoShift.id,
          cycleStartIndex: 0,
        ),
      );
      expect(encoded, startsWith('교대:'));

      final parsed = WorkScheduleCodec.tryParse(encoded)!;
      expect(parsed.mode, WorkScheduleMode.rotatingShift);
      expect(parsed.rotatingPresetId, RotatingShiftPreset.threeTeamTwoShift.id);
      expect(parsed.countWorkDays(), greaterThan(0));
    });

    test('round-trips daily pick for 일용직', () {
      final encoded = WorkScheduleCodec.encode(
        WorkScheduleSpec(
          mode: WorkScheduleMode.dailyPick,
          selectedWorkDates: {
            DateTime(2026, 5, 7),
            DateTime(2026, 5, 9),
            DateTime(2026, 5, 12),
          },
          dayStart: TimeOfDay(hour: 8, minute: 30),
          dayEnd: TimeOfDay(hour: 17, minute: 30),
        ).withDerivedDailyBounds(),
      );
      expect(encoded, startsWith('일용 ·'));
      expect(encoded, contains('2026-05-07'));
      expect(encoded, contains('근무3일'));

      final parsed = WorkScheduleCodec.tryParse(encoded)!;
      expect(parsed.mode, WorkScheduleMode.dailyPick);
      expect(parsed.countWorkDays(), 3);
      expect(parsed.slotOn(DateTime(2026, 5, 9)), ShiftSlotKind.day);
      expect(parsed.slotOn(DateTime(2026, 5, 8)), ShiftSlotKind.off);
    });

    test('parses legacy date range', () {
      final parsed =
          WorkScheduleCodec.tryParse('2026-05-01 ~ 2026-05-10 · 10:00~19:00');
      expect(parsed, isNotNull);
      expect(parsed!.startDate, DateTime(2026, 5, 1));
      expect(parsed.dayStart, const TimeOfDay(hour: 10, minute: 0));
    });

    test('round-trips custom dates with exclusions', () {
      final encoded = WorkScheduleCodec.encode(
        WorkScheduleSpec(
          mode: WorkScheduleMode.customDates,
          startDate: DateTime(2026, 5, 7),
          endDate: DateTime(2026, 5, 10),
          customExcludedDates: {DateTime(2026, 5, 8)},
        ),
      );
      expect(encoded, contains('제외='));
      final parsed = WorkScheduleCodec.tryParse(encoded)!;
      expect(parsed.countWorkDays(), 3);
    });

    test('round-trips custom rotating direct select', () {
      final encoded = WorkScheduleCodec.encode(
        WorkScheduleSpec(
          mode: WorkScheduleMode.rotatingShift,
          startDate: DateTime(2026, 5, 7),
          endDate: DateTime(2026, 5, 20),
          rotatingPresetId: RotatingShiftPreset.customDirect.id,
          customCycle: const [
            ShiftSlotKind.day,
            ShiftSlotKind.off,
            ShiftSlotKind.night,
          ],
        ),
      );
      expect(encoded, contains('직접선택'));
      final parsed = WorkScheduleCodec.tryParse(encoded)!;
      expect(parsed.rotatingPresetId, RotatingShiftPreset.customDirect.id);
      expect(parsed.customCycle.length, 3);
    });

    test('cross-month fixed weekdays counts work days', () {
      final spec = WorkScheduleSpec(
        mode: WorkScheduleMode.fixedWeekdays,
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 6, 10),
        weekdays: {0, 1, 2, 3, 4},
      );
      expect(spec.countWorkDays(), 16);

      final encoded = WorkScheduleCodec.encode(spec);
      expect(encoded, contains('2026-05-20~2026-06-10'));
      final parsed = WorkScheduleCodec.tryParse(encoded)!;
      expect(parsed.countWorkDays(), 16);
    });

    test('cross-month rotating shift slotOn', () {
      final spec = WorkScheduleSpec(
        mode: WorkScheduleMode.rotatingShift,
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 6, 10),
        rotatingPresetId: RotatingShiftPreset.threeTeamTwoShift.id,
      );
      expect(spec.slotOn(DateTime(2026, 5, 20)), isNotNull);
      expect(spec.slotOn(DateTime(2026, 6, 1)), isNotNull);
      expect(spec.slotOn(DateTime(2026, 6, 11)), isNull);
    });

    test('single-day period is valid', () {
      final spec = WorkScheduleSpec(
        mode: WorkScheduleMode.fixedWeekdays,
        startDate: DateTime(2026, 5, 20),
        endDate: DateTime(2026, 5, 20),
        weekdays: {0, 1, 2, 3, 4},
      );
      expect(spec.isComplete, isTrue);
      expect(spec.countWorkDays(), 1);
      final encoded = WorkScheduleCodec.encode(spec);
      expect(encoded, contains('2026-05-20~2026-05-20'));
    });

    test('slotOn for 4조3교대 cycles', () {
      final spec = WorkScheduleSpec(
        mode: WorkScheduleMode.rotatingShift,
        startDate: DateTime(2026, 5, 7),
        endDate: DateTime(2026, 5, 14),
        rotatingPresetId: RotatingShiftPreset.fourTeamThreeShiftRyybb.id,
        cycleStartIndex: 0,
      );
      expect(spec.slotOn(DateTime(2026, 5, 7)), ShiftSlotKind.day);
      expect(spec.slotOn(DateTime(2026, 5, 8)), ShiftSlotKind.night);
      expect(spec.slotOn(DateTime(2026, 5, 10)), ShiftSlotKind.off);
    });
  });

  testWidgets('WorkScheduleSelectorField opens sheet with modes', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkScheduleSelectorField(controller: controller),
        ),
      ),
    );

    await tester.tap(find.text('근무 일정 선택'));
    await tester.pumpAndSettle();

    expect(find.text('요일 고정'), findsOneWidget);
    expect(find.text('교대 순환'), findsOneWidget);
    expect(find.text('날짜 맞춤'), findsOneWidget);
  });

  testWidgets('WorkScheduleSelectorField dailyOnly hides mode tabs', (tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkScheduleSelectorField(
            controller: controller,
            dailyOnly: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('근무일 선택'));
    await tester.pumpAndSettle();

    expect(find.text('요일 고정'), findsNothing);
    expect(find.text('교대 순환'), findsNothing);
    expect(find.text('날짜 맞춤'), findsNothing);
    expect(find.text('달력에서 근무일을 하루씩 탭해 선택·해제하세요.'), findsOneWidget);
  });
}
