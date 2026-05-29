import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/calendar/korean_public_holidays.dart';
import 'package:map/core/widgets/korean_calendar.dart';

void main() {
  test('Sunday-first leading blanks', () {
    // 2025-06-01 is Sunday
    expect(
      KoreanCalendarLayout.leadingBlankDays(DateTime(2025, 6, 1)),
      0,
    );
    // 2025-06-02 is Monday
    expect(
      KoreanCalendarLayout.leadingBlankDays(DateTime(2025, 6, 2)),
      1,
    );
  });

  test('weekday header colors', () {
    expect(
      KoreanCalendarLayout.weekdayHeaderColor(0),
      const Color(0xFFE53935),
    );
    expect(
      KoreanCalendarLayout.weekdayHeaderColor(6),
      const Color(0xFF1E88E5),
    );
  });

  test('day text color for Saturday and holiday', () {
    expect(
      KoreanCalendarLayout.dayTextColor(DateTime(2025, 6, 7)).value,
      const Color(0xFF1E88E5).value,
    );
    expect(
      KoreanCalendarLayout.dayTextColor(DateTime(2025, 1, 1)).value,
      const Color(0xFFE53935).value,
    );
    expect(KoreanPublicHolidays.isHoliday(DateTime(2025, 10, 3)), isTrue);
  });
}
