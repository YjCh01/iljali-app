import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';

/// 공고 근무 일정 달력 — 기간·월 목록·지원 가능 근무일
extension WorkScheduleCalendarX on WorkScheduleSpec {
  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  (DateTime?, DateTime?) periodBounds() {
    if (firstStartDateOnly) {
      if (startDate == null) return (null, null);
      final s = dateOnly(startDate!);
      return (s, s);
    }
    if (startDate == null) return (null, null);
    if (endDate == null) {
      final s = dateOnly(startDate!);
      return (s, s);
    }
    return (dateOnly(startDate!), dateOnly(endDate!));
  }

  List<DateTime> monthsToShow() {
    final now = DateTime.now();
    var minMonth = DateTime(now.year, now.month);
    var maxMonth = DateTime(now.year, now.month);

    for (final date in [
      startDate,
      endDate,
      ...selectedWorkDates,
    ]) {
      if (date == null) continue;
      final m = DateTime(date.year, date.month);
      if (m.isBefore(minMonth)) minMonth = m;
      if (m.isAfter(maxMonth)) maxMonth = m;
    }

    final rangeStart = DateTime(minMonth.year, minMonth.month - 1);
    var rangeEnd = DateTime(maxMonth.year, maxMonth.month + 2);
    final minSpanEnd = DateTime(rangeStart.year, rangeStart.month + 14);
    if (rangeEnd.isBefore(minSpanEnd)) rangeEnd = minSpanEnd;

    final months = <DateTime>[];
    var cursor = rangeStart;
    while (!cursor.isAfter(rangeEnd)) {
      months.add(DateTime(cursor.year, cursor.month));
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return months;
  }

  bool isEmployerWorkDay(DateTime date) {
    final d = dateOnly(date);
    if (mode == WorkScheduleMode.dailyPick) {
      return selectedWorkDates.any(
        (e) => e.year == d.year && e.month == d.month && e.day == d.day,
      );
    }
    final slot = slotOn(d);
    return slot == ShiftSlotKind.day || slot == ShiftSlotKind.night;
  }

  bool isSeekerSelectableDay(DateTime date) {
    final d = dateOnly(date);
    final today = dateOnly(DateTime.now());
    if (d.isBefore(today)) return false;
    return isEmployerWorkDay(d);
  }

  /// 지원자가 고를 수 있는 근무일 (오늘 이후, 공고 일정 기준)
  List<DateTime> seekerSelectableWorkDays() {
    if (mode == WorkScheduleMode.dailyPick) {
      final today = dateOnly(DateTime.now());
      final days = selectedWorkDates
          .map(dateOnly)
          .where((d) => !d.isBefore(today))
          .toList()
        ..sort();
      return days;
    }

    final today = dateOnly(DateTime.now());
    final bounds = _seekerScanBounds(today);
    if (bounds == null) return const [];

    final (from, to) = bounds;
    final days = <DateTime>[];
    var cursor = from;
    while (!cursor.isAfter(to)) {
      if (isSeekerSelectableDay(cursor)) {
        days.add(cursor);
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return days;
  }

  (DateTime, DateTime)? _seekerScanBounds(DateTime today) {
    if (firstStartDateOnly && endDate == null) {
      final anchor = startDate != null ? dateOnly(startDate!) : today;
      final from = anchor.isBefore(today) ? today : anchor;
      final to = DateTime(from.year + 1, from.month, from.day);
      return (from, to);
    }
    if (startDate == null) return null;

    final periodStart = dateOnly(startDate!);
    final periodEnd = endDate != null
        ? dateOnly(endDate!)
        : DateTime(periodStart.year + 1, periodStart.month, periodStart.day);

    final from = periodStart.isBefore(today) ? today : periodStart;
    if (from.isAfter(periodEnd)) return null;
    return (from, periodEnd);
  }
}
