import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/daily_worker_policy.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

void main() {
  group('DailyWorkerPolicy', () {
    test('paymentDatesFromWorkSchedule returns day after each work date', () {
      final spec = WorkScheduleSpec(
        mode: WorkScheduleMode.dailyPick,
        selectedWorkDates: {
          DateTime(2026, 6, 10),
          DateTime(2026, 6, 15),
          DateTime(2026, 6, 12),
        },
        dayStart: const TimeOfDay(hour: 9, minute: 0),
        dayEnd: const TimeOfDay(hour: 18, minute: 0),
      ).withDerivedDailyBounds();

      final schedule = WorkScheduleCodec.encode(spec);
      final paymentDates =
          DailyWorkerPolicy.paymentDatesFromWorkSchedule(schedule);

      expect(
        paymentDates,
        [
          DateTime(2026, 6, 11),
          DateTime(2026, 6, 13),
          DateTime(2026, 6, 16),
        ],
      );
    });

    test('paymentDatesFromWorkSchedule returns empty without work dates', () {
      expect(
        DailyWorkerPolicy.paymentDatesFromWorkSchedule(''),
        isEmpty,
      );
    });
  });
}
