/// 근무 일정 문자열에서 1일 총 근무시간(시간) 추출
import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';

abstract final class WorkHoursCalculator {
  /// 표준 주간 근무(예: 09:00~18:00)에서 차감하는 휴게시간
  static const double standardBreakHours = 1.0;

  static final _timeRangePattern = RegExp(
    r'(\d{1,2}):(\d{2})\s*[~\-–—]\s*(\d{1,2}):(\d{2})',
  );

  static double? dailyHoursFromSchedule(String schedule) {
    final spec = WorkScheduleCodec.tryParse(schedule);
    if (spec != null) {
      return _hoursFromSpec(spec);
    }

    final matches = _timeRangePattern.allMatches(schedule);
    if (matches.isEmpty) return null;

    var totalMinutes = 0;
    var hasDaytimeShift = false;
    for (final match in matches) {
      final startHour = int.parse(match.group(1)!);
      final startMinute = int.parse(match.group(2)!);
      final endHour = int.parse(match.group(3)!);
      final endMinute = int.parse(match.group(4)!);

      final start = startHour * 60 + startMinute;
      var end = endHour * 60 + endMinute;
      final overnight = end <= start;
      if (overnight) {
        end += 24 * 60;
      }
      totalMinutes += end - start;
      if (!overnight && start >= 6 * 60 && end <= 22 * 60) {
        hasDaytimeShift = true;
      }
    }

    if (totalMinutes <= 0) return null;

    var hours = totalMinutes / 60.0;
    if (hasDaytimeShift) {
      hours -= standardBreakHours;
    }
    if (hours <= 0) return null;
    return hours;
  }

  static double? _hoursFromSpec(WorkScheduleSpec spec) {
    if (spec.mode == WorkScheduleMode.dailyPick) {
      if (spec.selectedWorkDates.isEmpty) return null;
      var total = 0.0;
      var count = 0;
      for (final date in spec.selectedWorkDates) {
        final hours = spec.hoursForDate(date);
        final dayHours =
            _hoursBetween(hours.start, hours.end, daytime: true);
        if (dayHours == null) continue;
        total += dayHours;
        count++;
      }
      if (count == 0) return null;
      return total / count;
    }

    if (spec.mode == WorkScheduleMode.fixedWeekdays && spec.hasVariedWeekdayHours) {
      var total = 0.0;
      var count = 0;
      for (final index in spec.weekdays) {
        final hours = spec.hoursForWeekday(index);
        final dayHours =
            _hoursBetween(hours.start, hours.end, daytime: true);
        if (dayHours == null) continue;
        total += dayHours;
        count++;
      }
      if (count == 0) return null;
      return total / count;
    }

    final dayHours = _hoursBetween(spec.dayStart, spec.dayEnd, daytime: true);
    if (spec.mode != WorkScheduleMode.rotatingShift) {
      return dayHours;
    }
    final nightHours =
        _hoursBetween(spec.nightStart, spec.nightEnd, daytime: false);
    if (dayHours == null && nightHours == null) return null;
    if (dayHours == null) return nightHours;
    if (nightHours == null) return dayHours;
    return dayHours > nightHours ? dayHours : nightHours;
  }

  static double? _hoursBetween(
    TimeOfDay start,
    TimeOfDay end, {
    required bool daytime,
  }) {
    final startMin = start.hour * 60 + start.minute;
    var endMin = end.hour * 60 + end.minute;
    if (endMin <= startMin) endMin += 24 * 60;
    var hours = (endMin - startMin) / 60.0;
    if (daytime && startMin >= 6 * 60 && endMin <= 22 * 60) {
      hours -= standardBreakHours;
    }
    if (hours <= 0) return null;
    return hours;
  }
}
