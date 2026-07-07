import 'package:flutter/material.dart';

/// 일용직 — 특정 근무일의 시작·종료 시각
@immutable
class DailyDayHours {
  const DailyDayHours({required this.start, required this.end});

  final TimeOfDay start;
  final TimeOfDay end;

  DailyDayHours copyWith({TimeOfDay? start, TimeOfDay? end}) {
    return DailyDayHours(
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is DailyDayHours &&
        start == other.start &&
        end == other.end;
  }

  @override
  int get hashCode => Object.hash(start, end);
}

/// 근무 일정 표현 방식 (오늘근무·교대달력류 앱 패턴 참고)
enum WorkScheduleMode {
  /// 고정 요일 — 월~금, 월~토 등
  fixedWeekdays,

  /// 순환 교대 — 3조2교대(주야휴), 4조3교대(주야야비비) 등
  rotatingShift,

  /// 비정기 — 기간 내 기본 전 근무, 제외일만 탭해 끔
  customDates,

  /// 일용직 — 달력에서 근무일을 하루씩 직접 선택
  dailyPick,
}

/// 교대 슬롯 유형
enum ShiftSlotKind {
  day('주', '주간'),
  night('야', '야간'),
  off('휴', '휴무'),
  standby('비', '비번');

  const ShiftSlotKind(this.shortLabel, this.label);

  final String shortLabel;
  final String label;
}

/// 순환 교대 프리셋 (한국 현장에서 흔한 패턴)
class RotatingShiftPreset {
  const RotatingShiftPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.cycle,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<ShiftSlotKind> cycle;

  String get patternLabel => cycle.map((s) => s.shortLabel).join('');

  static const customDirect = RotatingShiftPreset(
    id: 'custom',
    title: '직접 선택',
    subtitle: '조·교대 패턴 직접 구성',
    cycle: [],
  );

  static const threeTeamTwoShift = RotatingShiftPreset(
    id: '3t2_ryo',
    title: '3조 2교대',
    subtitle: '주·야·휴 (주야휴)',
    cycle: [ShiftSlotKind.day, ShiftSlotKind.night, ShiftSlotKind.off],
  );

  static const fourTeamThreeShiftRyybb = RotatingShiftPreset(
    id: '4t3_ryybb',
    title: '4조 3교대',
    subtitle: '주·야·야·휴 (주야야비)',
    cycle: [
      ShiftSlotKind.day,
      ShiftSlotKind.night,
      ShiftSlotKind.night,
      ShiftSlotKind.off,
    ],
  );

  static const fourTeamThreeShiftRyhb = RotatingShiftPreset(
    id: '4t3_ryhb',
    title: '4조 3교대',
    subtitle: '주·야·휴·비 (주야휴비)',
    cycle: [
      ShiftSlotKind.day,
      ShiftSlotKind.night,
      ShiftSlotKind.off,
      ShiftSlotKind.standby,
    ],
  );

  static const twoShift = RotatingShiftPreset(
    id: '2shift',
    title: '2교대',
    subtitle: '주·야 반복',
    cycle: [ShiftSlotKind.day, ShiftSlotKind.night],
  );

  static const fiveTeamThreeShift = RotatingShiftPreset(
    id: '5t3',
    title: '5조 3교대',
    subtitle: '주·야·휴·휴·휴',
    cycle: [
      ShiftSlotKind.day,
      ShiftSlotKind.night,
      ShiftSlotKind.off,
      ShiftSlotKind.off,
      ShiftSlotKind.off,
    ],
  );

  static const all = [
    threeTeamTwoShift,
    fourTeamThreeShiftRyybb,
    fourTeamThreeShiftRyhb,
    twoShift,
    fiveTeamThreeShift,
    customDirect,
  ];

  static RotatingShiftPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// 공고용 근무 일정 명세
class WorkScheduleSpec {
  WorkScheduleSpec({
    this.mode = WorkScheduleMode.fixedWeekdays,
    this.startDate,
    this.endDate,
    this.firstStartDateOnly = false,
    this.weekdays = const {0, 1, 2, 3, 4},
    this.rotatingPresetId = '3t2_ryo',
    this.cycleStartIndex = 0,
    this.customCycle = const [
      ShiftSlotKind.day,
      ShiftSlotKind.night,
      ShiftSlotKind.off,
    ],
    this.customExcludedDates = const {},
    this.selectedWorkDates = const {},
    this.dailyHoursByDate = const {},
    this.weekdayHoursByIndex = const {},
    this.dayStart = const TimeOfDay(hour: 9, minute: 0),
    this.dayEnd = const TimeOfDay(hour: 18, minute: 0),
    this.nightStart = const TimeOfDay(hour: 22, minute: 0),
    this.nightEnd = const TimeOfDay(hour: 6, minute: 0),
  });

  final WorkScheduleMode mode;
  final DateTime? startDate;
  final DateTime? endDate;

  /// 정규직 — 종료일 없이 첫 근무 시작일만 지정
  final bool firstStartDateOnly;

  /// 0=월 … 6=일
  final Set<int> weekdays;

  final String rotatingPresetId;
  final int cycleStartIndex;

  /// 직접 선택 교대 패턴
  final List<ShiftSlotKind> customCycle;

  /// 날짜 맞춤 — 제외일 (기간 내 기본은 전부 근무)
  final Set<DateTime> customExcludedDates;

  /// 일용직 — 선택한 근무일
  final Set<DateTime> selectedWorkDates;

  /// 일용직 — 날짜별 근무 시간 (키: yyyy-MM-dd). 없으면 [dayStart]/[dayEnd] 사용
  final Map<String, DailyDayHours> dailyHoursByDate;

  /// 요일 고정·날짜 맞춤 — 요일(0=월…6=일)별 근무 시간. 없으면 [dayStart]/[dayEnd] 사용
  final Map<int, DailyDayHours> weekdayHoursByIndex;

  final TimeOfDay dayStart;
  final TimeOfDay dayEnd;
  final TimeOfDay nightStart;
  final TimeOfDay nightEnd;

  static const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  static String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DailyDayHours hoursForWeekday(int weekdayIndex) {
    return weekdayHoursByIndex[weekdayIndex] ??
        DailyDayHours(start: dayStart, end: dayEnd);
  }

  DailyDayHours hoursForDate(DateTime date) {
    if (mode == WorkScheduleMode.dailyPick) {
      return dailyHoursByDate[dateKey(date)] ??
          DailyDayHours(start: dayStart, end: dayEnd);
    }
    if (mode == WorkScheduleMode.fixedWeekdays ||
        mode == WorkScheduleMode.customDates) {
      return hoursForWeekday(weekdayIndex(date));
    }
    return DailyDayHours(start: dayStart, end: dayEnd);
  }

  bool get hasVariedWeekdayHours {
    if (mode != WorkScheduleMode.fixedWeekdays &&
        mode != WorkScheduleMode.customDates) {
      return false;
    }
    final indices = mode == WorkScheduleMode.fixedWeekdays
        ? weekdays.toList()
        : List<int>.generate(7, (i) => i);
    if (indices.isEmpty) return false;
    DailyDayHours? baseline;
    for (final index in indices) {
      final hours = hoursForWeekday(index);
      baseline ??= hours;
      if (hours != baseline) return true;
    }
    return false;
  }

  bool get hasVariedDailyHours {
    if (mode != WorkScheduleMode.dailyPick || selectedWorkDates.isEmpty) {
      return false;
    }
    DailyDayHours? baseline;
    for (final date in selectedWorkDates) {
      final hours = hoursForDate(date);
      baseline ??= hours;
      if (hours != baseline) return true;
    }
    return false;
  }

  static int weekdayIndex(DateTime date) => (date.weekday + 6) % 7;

  bool isWeekdayAllowed(DateTime date) =>
      weekdays.contains(weekdayIndex(date));

  List<ShiftSlotKind> get rotatingCycle {
    if (rotatingPresetId == RotatingShiftPreset.customDirect.id) {
      return customCycle;
    }
    return RotatingShiftPreset.byId(rotatingPresetId)?.cycle ?? const [];
  }

  bool get isComplete => isCompleteFor();

  bool isCompleteFor({
    bool workPeriodNegotiable = false,
    bool workScheduleNegotiable = false,
  }) {
    if (workScheduleNegotiable) return true;
    if (firstStartDateOnly) {
      final hasStart = startDate != null;
      return switch (mode) {
        WorkScheduleMode.fixedWeekdays =>
          weekdays.isNotEmpty && (hasStart || workPeriodNegotiable),
        WorkScheduleMode.rotatingShift =>
          rotatingCycle.isNotEmpty && (hasStart || workPeriodNegotiable),
        WorkScheduleMode.customDates => hasStart || workPeriodNegotiable,
        WorkScheduleMode.dailyPick => selectedWorkDates.isNotEmpty,
      };
    }
    return switch (mode) {
      WorkScheduleMode.fixedWeekdays =>
        startDate != null && endDate != null && weekdays.isNotEmpty,
      WorkScheduleMode.rotatingShift =>
        startDate != null && endDate != null && rotatingCycle.isNotEmpty,
      WorkScheduleMode.customDates =>
        startDate != null && endDate != null && countWorkDays() > 0,
      WorkScheduleMode.dailyPick => selectedWorkDates.isNotEmpty,
    };
  }

  WorkScheduleSpec copyWith({
    WorkScheduleMode? mode,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? firstStartDateOnly,
    Set<int>? weekdays,
    String? rotatingPresetId,
    int? cycleStartIndex,
    List<ShiftSlotKind>? customCycle,
    Set<DateTime>? customExcludedDates,
    Set<DateTime>? selectedWorkDates,
    Map<String, DailyDayHours>? dailyHoursByDate,
    Map<int, DailyDayHours>? weekdayHoursByIndex,
    TimeOfDay? dayStart,
    TimeOfDay? dayEnd,
    TimeOfDay? nightStart,
    TimeOfDay? nightEnd,
  }) {
    return WorkScheduleSpec(
      mode: mode ?? this.mode,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      firstStartDateOnly: firstStartDateOnly ?? this.firstStartDateOnly,
      weekdays: weekdays ?? this.weekdays,
      rotatingPresetId: rotatingPresetId ?? this.rotatingPresetId,
      cycleStartIndex: cycleStartIndex ?? this.cycleStartIndex,
      customCycle: customCycle ?? this.customCycle,
      customExcludedDates: customExcludedDates ?? this.customExcludedDates,
      selectedWorkDates: selectedWorkDates ?? this.selectedWorkDates,
      dailyHoursByDate: dailyHoursByDate ?? this.dailyHoursByDate,
      weekdayHoursByIndex: weekdayHoursByIndex ?? this.weekdayHoursByIndex,
      dayStart: dayStart ?? this.dayStart,
      dayEnd: dayEnd ?? this.dayEnd,
      nightStart: nightStart ?? this.nightStart,
      nightEnd: nightEnd ?? this.nightEnd,
    );
  }

  bool _isExcluded(DateTime d) {
    return customExcludedDates.any(
      (e) => e.year == d.year && e.month == d.month && e.day == d.day,
    );
  }

  bool _isSelectedWorkDay(DateTime d) {
    return selectedWorkDates.any(
      (e) => e.year == d.year && e.month == d.month && e.day == d.day,
    );
  }

  /// 특정 날짜의 슬롯 (교대·고정·맞춤·일용 통합)
  ShiftSlotKind? slotOn(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);

    if (mode == WorkScheduleMode.dailyPick) {
      return _isSelectedWorkDay(d) ? ShiftSlotKind.day : ShiftSlotKind.off;
    }

    if (firstStartDateOnly) {
      if (startDate == null) return null;
      final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
      final day = DateTime(d.year, d.month, d.day);
      if (day.isBefore(s)) return null;
      if (endDate != null) {
        final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
        if (day.isAfter(e)) return null;
      }
      return switch (mode) {
        WorkScheduleMode.fixedWeekdays =>
          isWeekdayAllowed(day) ? ShiftSlotKind.day : ShiftSlotKind.off,
        WorkScheduleMode.rotatingShift => _rotatingSlotOn(day, s),
        WorkScheduleMode.customDates =>
          _isExcluded(day) ? ShiftSlotKind.off : ShiftSlotKind.day,
        WorkScheduleMode.dailyPick => null,
      };
    }

    if (startDate == null || endDate == null) return null;
    final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
    if (d.isBefore(s) || d.isAfter(e)) return null;

    return switch (mode) {
      WorkScheduleMode.fixedWeekdays =>
        isWeekdayAllowed(d) ? ShiftSlotKind.day : ShiftSlotKind.off,
      WorkScheduleMode.rotatingShift => _rotatingSlotOn(d, s),
      WorkScheduleMode.customDates =>
        _isExcluded(d) ? ShiftSlotKind.off : ShiftSlotKind.day,
      WorkScheduleMode.dailyPick => null,
    };
  }

  ShiftSlotKind? _rotatingSlotOn(DateTime d, DateTime anchor) {
    final cycle = rotatingCycle;
    if (cycle.isEmpty) return null;
    final days = d.difference(anchor).inDays;
    final index = (days + cycleStartIndex) % cycle.length;
    return cycle[index];
  }

  /// 근무일 수 (기간 내)
  int countWorkDays() {
    if (mode == WorkScheduleMode.dailyPick) {
      return selectedWorkDates.length;
    }
    if (firstStartDateOnly && endDate == null) {
      return 0;
    }
    if (startDate == null || endDate == null) return 0;
    var count = 0;
    var cursor = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    while (!cursor.isAfter(end)) {
      final slot = slotOn(cursor);
      if (slot == ShiftSlotKind.day || slot == ShiftSlotKind.night) {
        count++;
      }
      cursor = cursor.add(const Duration(days: 1));
    }
    return count;
  }

  /// 기간 변경 시 범위 밖 제외일 정리
  WorkScheduleSpec trimExcludedDatesToRange() {
    if (startDate == null || endDate == null) {
      return copyWith(customExcludedDates: {});
    }
    final s = DateTime(startDate!.year, startDate!.month, startDate!.day);
    final e = DateTime(endDate!.year, endDate!.month, endDate!.day);
    final trimmed = customExcludedDates.where((d) {
      final day = DateTime(d.year, d.month, d.day);
      return !day.isBefore(s) && !day.isAfter(e);
    }).toSet();
    return copyWith(customExcludedDates: trimmed);
  }

  WorkScheduleSpec trimWeekdayHoursToSelection() {
    if (mode == WorkScheduleMode.fixedWeekdays) {
      final trimmed = {
        for (final entry in weekdayHoursByIndex.entries)
          if (weekdays.contains(entry.key)) entry.key: entry.value,
      };
      return copyWith(weekdayHoursByIndex: trimmed);
    }
    return this;
  }

  WorkScheduleSpec trimDailyHoursToSelection() {
    final keys = selectedWorkDates.map(dateKey).toSet();
    final trimmed = {
      for (final entry in dailyHoursByDate.entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
    return copyWith(dailyHoursByDate: trimmed);
  }

  WorkScheduleSpec withDerivedDailyBounds() {
    if (selectedWorkDates.isEmpty) {
      return copyWith(clearStartDate: true, clearEndDate: true);
    }
    final sorted = selectedWorkDates.toList()..sort();
    return copyWith(
      startDate: sorted.first,
      endDate: sorted.last,
    ).trimDailyHoursToSelection();
  }
}
