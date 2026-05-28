import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/widgets/scroll_time_picker.dart';

void main() {
  group('snapTimeToHalfHour', () {
    test('snaps to 00 when minute <= 15', () {
      expect(
        snapTimeToHalfHour(const TimeOfDay(hour: 9, minute: 4)),
        const TimeOfDay(hour: 9, minute: 0),
      );
    });

    test('snaps to 30 when minute between 16 and 45', () {
      expect(
        snapTimeToHalfHour(const TimeOfDay(hour: 4, minute: 21)),
        const TimeOfDay(hour: 4, minute: 30),
      );
    });

    test('rolls to next hour 00 when minute > 45', () {
      expect(
        snapTimeToHalfHour(const TimeOfDay(hour: 23, minute: 50)),
        const TimeOfDay(hour: 0, minute: 0),
      );
    });
  });
}
