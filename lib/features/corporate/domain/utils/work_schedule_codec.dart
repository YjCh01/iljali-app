import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';

/// 근무 일정 ↔ 공고 `workSchedule` 문자열 변환
abstract final class WorkScheduleCodec {
  static final _dateRangePattern = RegExp(
    r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})\s*[~\-–—]\s*(\d{4})[./-](\d{1,2})[./-](\d{1,2})',
  );
  static final _timePattern = RegExp(
    r'(\d{1,2}):(\d{2})\s*[~\-–—]\s*(\d{1,2}):(\d{2})',
  );

  static WorkScheduleSpec? tryParse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    final regular = text.startsWith('정규·') || text.startsWith('정규 ·');
    final body = regular
        ? text.replaceFirst(RegExp(r'^정규\s*·\s*'), '')
        : text;

    if (body.startsWith('일용 ·') || body.startsWith('일용·')) {
      return _parseDailyPick(body);
    }
    if (body.startsWith('교대:')) {
      return _parseRotating(body, firstStartDateOnly: regular);
    }
    if (body.startsWith('맞춤 ·') || body.startsWith('맞춤·')) {
      return _parseCustom(body, firstStartDateOnly: regular);
    }
    if (body.contains('주') && body.contains('일(')) {
      return _parseFixedWeekdays(body, firstStartDateOnly: regular);
    }

    if (!regular) {
      final legacy = _parseLegacyDateRange(body);
      if (legacy != null) return legacy;
    }

    return null;
  }

  static String encode(
    WorkScheduleSpec spec, {
    bool workPeriodNegotiable = false,
    bool workScheduleNegotiable = false,
  }) {
    if (workScheduleNegotiable &&
        !spec.isCompleteFor(workPeriodNegotiable: workPeriodNegotiable)) {
      return WorkScheduleNegotiable.label;
    }
    if (!spec.isCompleteFor(
      workPeriodNegotiable: workPeriodNegotiable,
      workScheduleNegotiable: workScheduleNegotiable,
    )) {
      return '';
    }
    final dayTime = '${_padTime(spec.dayStart)}~${_padTime(spec.dayEnd)}';
    final prefix = spec.firstStartDateOnly ? '정규·' : '';

    return switch (spec.mode) {
      WorkScheduleMode.dailyPick => () {
          final sorted = spec.selectedWorkDates.toList()
            ..sort((a, b) => a.compareTo(b));
          if (spec.hasVariedDailyHours) {
            final dated = sorted
                .map((date) {
                  final hours = spec.hoursForDate(date);
                  return '${_fmtDate(date)}@${_padTime(hours.start)}~${_padTime(hours.end)}';
                })
                .join(',');
            return '일용 · $dated · 근무${sorted.length}일';
          }
          final dates = sorted.map(_fmtDate).join(',');
          return '일용 · $dates · $dayTime · 근무${sorted.length}일';
        }(),
      WorkScheduleMode.fixedWeekdays => () {
          final days = WorkScheduleSpec.weekdayLabels
              .asMap()
              .entries
              .where((e) => spec.weekdays.contains(e.key))
              .map((e) => e.value)
              .join('');
          final count = spec.weekdays.length;
          final timePart = spec.hasVariedWeekdayHours
              ? _encodeWeekdayHours(spec)
              : dayTime;
          if (spec.firstStartDateOnly) {
            final startPart =
                spec.startDate != null ? '${_fmtDate(spec.startDate!)} · ' : '';
            return '${prefix}주${count}일($days) · $startPart$timePart';
          }
          final start = _fmtDate(spec.startDate!);
          final end = _fmtDate(spec.endDate!);
          return '주${count}일($days) · $start~$end · $timePart';
        }(),
      WorkScheduleMode.rotatingShift => () {
          final cycle = spec.rotatingCycle;
          final startSlot = cycle[spec.cycleStartIndex % cycle.length];
          final nightTime =
              '${_padTime(spec.nightStart)}~${_padTime(spec.nightEnd)}';
          final label = spec.rotatingPresetId ==
                  RotatingShiftPreset.customDirect.id
              ? '직접선택(${cycle.map((s) => s.shortLabel).join('')})'
              : () {
                  final preset =
                      RotatingShiftPreset.byId(spec.rotatingPresetId)!;
                  return '${preset.title}(${preset.patternLabel})';
                }();
          if (spec.firstStartDateOnly) {
            final startPart =
                spec.startDate != null ? '${_fmtDate(spec.startDate!)} · ' : '';
            return '${prefix}교대:$label · $startPart'
                '주$dayTime · 야$nightTime · '
                '시작=${startSlot.shortLabel}';
          }
          final start = _fmtDate(spec.startDate!);
          final end = _fmtDate(spec.endDate!);
          return '교대:$label · $start~$end · '
              '주$dayTime · 야$nightTime · '
              '시작=${startSlot.shortLabel}';
        }(),
      WorkScheduleMode.customDates => () {
          final timePart = spec.hasVariedWeekdayHours
              ? _encodeWeekdayHours(spec, allWeekdays: true)
              : dayTime;
          if (spec.firstStartDateOnly) {
            final startPart =
                spec.startDate != null ? '${_fmtDate(spec.startDate!)} · ' : '';
            final sorted = spec.customExcludedDates.toList()
              ..sort((a, b) => a.compareTo(b));
            final base = '${prefix}맞춤 · $startPart$timePart';
            if (sorted.isEmpty) return base;
            final excluded = sorted.map(_fmtDate).join(',');
            return '$base · 제외=$excluded';
          }
          final start = _fmtDate(spec.startDate!);
          final end = _fmtDate(spec.endDate!);
          final sorted = spec.customExcludedDates.toList()
            ..sort((a, b) => a.compareTo(b));
          final base =
              '맞춤 · $start~$end · $timePart · 근무${spec.countWorkDays()}일';
          if (sorted.isEmpty) return base;
          final excluded = sorted.map(_fmtDate).join(',');
          return '$base · 제외=$excluded';
        }(),
    };
  }

  static String _encodeWeekdayHours(
    WorkScheduleSpec spec, {
    bool allWeekdays = false,
  }) {
    final indices = allWeekdays
        ? List<int>.generate(7, (i) => i)
        : (spec.weekdays.toList()..sort());
    final parts = <String>[];
    for (final index in indices) {
      final label = WorkScheduleSpec.weekdayLabels[index];
      final hours = spec.hoursForWeekday(index);
      parts.add(
        '$label@${_padTime(hours.start)}~${_padTime(hours.end)}',
      );
    }
    return '요일=${parts.join(',')}';
  }

  static Map<int, DailyDayHours> _parseWeekdayHours(String text) {
    final weekdayHours = <int, DailyDayHours>{};
    final section = RegExp(r'요일=([^·]+)').firstMatch(text);
    final source = section?.group(1) ?? text;
    final pattern = RegExp(
      r'([월화수목금토일])@(\d{1,2}:\d{2})~(\d{1,2}:\d{2})',
    );
    for (final match in pattern.allMatches(source)) {
      final label = match.group(1)!;
      final index = WorkScheduleSpec.weekdayLabels.indexOf(label);
      if (index < 0) continue;
      weekdayHours[index] = DailyDayHours(
        start: _parseTimeParts(match.group(2)!),
        end: _parseTimeParts(match.group(3)!),
      );
    }
    return weekdayHours;
  }

  static String displayLabel(String raw) {
    final parsed = tryParse(raw);
    if (parsed != null && parsed.isComplete) {
      return encode(parsed);
    }
    return raw.trim();
  }

  static WorkScheduleSpec? _parseLegacyDateRange(String text) {
    final match = _dateRangePattern.firstMatch(text);
    if (match == null) return null;
    final start = _parseDate(match.group(1)!, match.group(2)!, match.group(3)!);
    final end = _parseDate(match.group(4)!, match.group(5)!, match.group(6)!);
    final times = _timePattern.allMatches(text).toList();
    TimeOfDay dayStart = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay dayEnd = const TimeOfDay(hour: 18, minute: 0);
    if (times.isNotEmpty) {
      dayStart = _parseTime(times.first);
      dayEnd = _parseTimeEnd(times.first);
    }
    return WorkScheduleSpec(
      mode: WorkScheduleMode.fixedWeekdays,
      startDate: start,
      endDate: end,
      weekdays: {0, 1, 2, 3, 4},
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
  }

  static WorkScheduleSpec? _parseFixedWeekdays(
    String text, {
    bool firstStartDateOnly = false,
  }) {
    if (firstStartDateOnly) {
      final weekdays = <int>{};
      final weekdaySection = RegExp(r'\(([월화수목금토일]+)\)').firstMatch(text);
      if (weekdaySection != null) {
        final chars = weekdaySection.group(1)!;
        for (var i = 0; i < WorkScheduleSpec.weekdayLabels.length; i++) {
          if (chars.contains(WorkScheduleSpec.weekdayLabels[i])) {
            weekdays.add(i);
          }
        }
      }
      if (weekdays.isEmpty) weekdays.addAll([0, 1, 2, 3, 4]);

      final single = _singleDatePattern.firstMatch(text);
      final times = _timePattern.firstMatch(text);
      var dayStart = const TimeOfDay(hour: 9, minute: 0);
      var dayEnd = const TimeOfDay(hour: 18, minute: 0);
      if (times != null && !text.contains('@')) {
        dayStart = _parseTime(times);
        dayEnd = _parseTimeEnd(times);
      }
      final weekdayHours = _parseWeekdayHours(text);
      if (weekdayHours.isNotEmpty) {
        final first = weekdayHours.values.first;
        dayStart = first.start;
        dayEnd = first.end;
      }

      return WorkScheduleSpec(
        mode: WorkScheduleMode.fixedWeekdays,
        firstStartDateOnly: true,
        startDate: single != null
            ? _parseDate(
                single.group(1)!,
                single.group(2)!,
                single.group(3)!,
              )
            : null,
        weekdays: weekdays,
        weekdayHoursByIndex: weekdayHours,
        dayStart: dayStart,
        dayEnd: dayEnd,
      );
    }

    final range = _dateRangePattern.firstMatch(text);
    if (range == null) return null;
    final start =
        _parseDate(range.group(1)!, range.group(2)!, range.group(3)!);
    final end =
        _parseDate(range.group(4)!, range.group(5)!, range.group(6)!);

    final weekdays = <int>{};
    final weekdaySection = RegExp(r'\(([월화수목금토일]+)\)').firstMatch(text);
    if (weekdaySection != null) {
      final chars = weekdaySection.group(1)!;
      for (var i = 0; i < WorkScheduleSpec.weekdayLabels.length; i++) {
        if (chars.contains(WorkScheduleSpec.weekdayLabels[i])) {
          weekdays.add(i);
        }
      }
    }
    if (weekdays.isEmpty) weekdays.addAll([0, 1, 2, 3, 4]);

    final times = _timePattern.firstMatch(text);
    var dayStart = const TimeOfDay(hour: 9, minute: 0);
    var dayEnd = const TimeOfDay(hour: 18, minute: 0);
    if (times != null && !text.contains('@')) {
      dayStart = _parseTime(times);
      dayEnd = _parseTimeEnd(times);
    }
    final weekdayHours = _parseWeekdayHours(text);
    if (weekdayHours.isNotEmpty) {
      final first = weekdayHours.values.first;
      dayStart = first.start;
      dayEnd = first.end;
    }

    return WorkScheduleSpec(
      mode: WorkScheduleMode.fixedWeekdays,
      startDate: start,
      endDate: end,
      weekdays: weekdays,
      weekdayHoursByIndex: weekdayHours,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
  }

  static WorkScheduleSpec? _parseDailyPick(String text) {
    var dayStart = const TimeOfDay(hour: 9, minute: 0);
    var dayEnd = const TimeOfDay(hour: 18, minute: 0);

    final workDates = <DateTime>{};
    final dailyHours = <String, DailyDayHours>{};
    final sections = text.split('·').map((s) => s.trim()).toList();
    if (sections.isEmpty || !sections.first.startsWith('일용')) return null;

    final dateSection = sections.length > 1 ? sections[1] : '';
    final perDayPattern = RegExp(
      r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})@(\d{1,2}:\d{2})~(\d{1,2}:\d{2})',
    );
    var hasPerDayTimes = false;

    for (final part in dateSection.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;

      final withTime = perDayPattern.firstMatch(trimmed);
      if (withTime != null) {
        hasPerDayTimes = true;
        final date = _parseDate(
          withTime.group(1)!,
          withTime.group(2)!,
          withTime.group(3)!,
        );
        workDates.add(date);
        final start = _parseTimeParts(withTime.group(4)!);
        final end = _parseTimeParts(withTime.group(5)!);
        dailyHours[WorkScheduleSpec.dateKey(date)] =
            DailyDayHours(start: start, end: end);
        continue;
      }

      final full = RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})')
          .firstMatch(trimmed);
      if (full != null) {
        workDates.add(_parseDate(
          full.group(1)!,
          full.group(2)!,
          full.group(3)!,
        ));
      }
    }
    if (workDates.isEmpty) return null;

    if (!hasPerDayTimes) {
      for (final section in sections.skip(2)) {
        final times = _timePattern.firstMatch(section);
        if (times != null) {
          dayStart = _parseTime(times);
          dayEnd = _parseTimeEnd(times);
          break;
        }
      }
    } else if (dailyHours.isNotEmpty) {
      final first = dailyHours.values.first;
      dayStart = first.start;
      dayEnd = first.end;
    }

    final sorted = workDates.toList()..sort();
    return WorkScheduleSpec(
      mode: WorkScheduleMode.dailyPick,
      selectedWorkDates: workDates,
      dailyHoursByDate: dailyHours,
      startDate: sorted.first,
      endDate: sorted.last,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
  }

  static final _singleDatePattern = RegExp(
    r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})',
  );

  static WorkScheduleSpec? _parseRotating(
    String text, {
    bool firstStartDateOnly = false,
  }) {
    if (firstStartDateOnly) {
      final single = _singleDatePattern.firstMatch(text);
      final start = single != null
          ? _parseDate(
              single.group(1)!,
              single.group(2)!,
              single.group(3)!,
            )
          : null;

      var presetId = RotatingShiftPreset.threeTeamTwoShift.id;
      var customCycle = const [
        ShiftSlotKind.day,
        ShiftSlotKind.night,
        ShiftSlotKind.off,
      ];

      if (text.contains('직접선택')) {
        presetId = RotatingShiftPreset.customDirect.id;
        final patternMatch =
            RegExp(r'직접선택\(([주야휴비]+)\)').firstMatch(text);
        if (patternMatch != null) {
          customCycle = _cycleFromLabel(patternMatch.group(1)!);
        }
      } else {
        for (final p in RotatingShiftPreset.all) {
          if (p.id == RotatingShiftPreset.customDirect.id) continue;
          if (text.contains(p.title) || text.contains(p.patternLabel)) {
            presetId = p.id;
            break;
          }
        }
      }

      final cycle = presetId == RotatingShiftPreset.customDirect.id
          ? customCycle
          : RotatingShiftPreset.byId(presetId)!.cycle;

      final dayMatch =
          RegExp(r'주(\d{1,2}:\d{2})~(\d{1,2}:\d{2})').firstMatch(text);
      final nightMatch =
          RegExp(r'야(\d{1,2}:\d{2})~(\d{1,2}:\d{2})').firstMatch(text);
      var dayStart = const TimeOfDay(hour: 9, minute: 0);
      var dayEnd = const TimeOfDay(hour: 18, minute: 0);
      var nightStart = const TimeOfDay(hour: 22, minute: 0);
      var nightEnd = const TimeOfDay(hour: 6, minute: 0);
      if (dayMatch != null) {
        dayStart = _parseTimeParts(dayMatch.group(1)!);
        dayEnd = _parseTimeParts(dayMatch.group(2)!);
      }
      if (nightMatch != null) {
        nightStart = _parseTimeParts(nightMatch.group(1)!);
        nightEnd = _parseTimeParts(nightMatch.group(2)!);
      }

      var cycleStart = 0;
      final startMatch = RegExp(r'시작=(\S)').firstMatch(text);
      if (startMatch != null) {
        final ch = startMatch.group(1)!;
        cycleStart = cycle.indexWhere((s) => s.shortLabel == ch);
        if (cycleStart < 0) cycleStart = 0;
      }

      return WorkScheduleSpec(
        mode: WorkScheduleMode.rotatingShift,
        firstStartDateOnly: true,
        startDate: start,
        rotatingPresetId: presetId,
        customCycle: customCycle,
        cycleStartIndex: cycleStart,
        dayStart: dayStart,
        dayEnd: dayEnd,
        nightStart: nightStart,
        nightEnd: nightEnd,
      );
    }

    final range = _dateRangePattern.firstMatch(text);
    if (range == null) return null;
    final start =
        _parseDate(range.group(1)!, range.group(2)!, range.group(3)!);
    final end =
        _parseDate(range.group(4)!, range.group(5)!, range.group(6)!);

    var presetId = RotatingShiftPreset.threeTeamTwoShift.id;
    var customCycle = const [
      ShiftSlotKind.day,
      ShiftSlotKind.night,
      ShiftSlotKind.off,
    ];

    if (text.contains('직접선택')) {
      presetId = RotatingShiftPreset.customDirect.id;
      final patternMatch =
          RegExp(r'직접선택\(([주야휴비]+)\)').firstMatch(text);
      if (patternMatch != null) {
        customCycle = _cycleFromLabel(patternMatch.group(1)!);
      }
    } else {
      for (final p in RotatingShiftPreset.all) {
        if (p.id == RotatingShiftPreset.customDirect.id) continue;
        if (text.contains(p.title) || text.contains(p.patternLabel)) {
          presetId = p.id;
          break;
        }
      }
    }

    final cycle = presetId == RotatingShiftPreset.customDirect.id
        ? customCycle
        : RotatingShiftPreset.byId(presetId)!.cycle;

    final dayMatch =
        RegExp(r'주(\d{1,2}:\d{2})~(\d{1,2}:\d{2})').firstMatch(text);
    final nightMatch =
        RegExp(r'야(\d{1,2}:\d{2})~(\d{1,2}:\d{2})').firstMatch(text);
    var dayStart = const TimeOfDay(hour: 9, minute: 0);
    var dayEnd = const TimeOfDay(hour: 18, minute: 0);
    var nightStart = const TimeOfDay(hour: 22, minute: 0);
    var nightEnd = const TimeOfDay(hour: 6, minute: 0);
    if (dayMatch != null) {
      dayStart = _parseTimeParts(dayMatch.group(1)!);
      dayEnd = _parseTimeParts(dayMatch.group(2)!);
    }
    if (nightMatch != null) {
      nightStart = _parseTimeParts(nightMatch.group(1)!);
      nightEnd = _parseTimeParts(nightMatch.group(2)!);
    }

    var cycleStart = 0;
    final startMatch = RegExp(r'시작=(\S)').firstMatch(text);
    if (startMatch != null) {
      final ch = startMatch.group(1)!;
      cycleStart = cycle.indexWhere((s) => s.shortLabel == ch);
      if (cycleStart < 0) cycleStart = 0;
    }

    return WorkScheduleSpec(
      mode: WorkScheduleMode.rotatingShift,
      startDate: start,
      endDate: end,
      rotatingPresetId: presetId,
      customCycle: customCycle,
      cycleStartIndex: cycleStart,
      dayStart: dayStart,
      dayEnd: dayEnd,
      nightStart: nightStart,
      nightEnd: nightEnd,
    );
  }

  static WorkScheduleSpec? _parseCustom(
    String text, {
    bool firstStartDateOnly = false,
  }) {
    if (firstStartDateOnly) {
      final single = _singleDatePattern.firstMatch(text);
      final start = single != null
          ? _parseDate(
              single.group(1)!,
              single.group(2)!,
              single.group(3)!,
            )
          : null;

      final times = _timePattern.firstMatch(text);
      var dayStart = const TimeOfDay(hour: 9, minute: 0);
      var dayEnd = const TimeOfDay(hour: 18, minute: 0);
      if (times != null && !text.contains('@')) {
        dayStart = _parseTime(times);
        dayEnd = _parseTimeEnd(times);
      }
      final weekdayHours = _parseWeekdayHours(text);
      if (weekdayHours.isNotEmpty) {
        final first = weekdayHours.values.first;
        dayStart = first.start;
        dayEnd = first.end;
      }

      final excluded = <DateTime>{};
      final excludeSection = RegExp(r'제외=([^·]+)').firstMatch(text);
      if (excludeSection != null) {
        for (final part in excludeSection.group(1)!.split(',')) {
          final full = _singleDatePattern.firstMatch(part.trim());
          if (full != null) {
            excluded.add(_parseDate(
              full.group(1)!,
              full.group(2)!,
              full.group(3)!,
            ));
          }
        }
      }

      return WorkScheduleSpec(
        mode: WorkScheduleMode.customDates,
        firstStartDateOnly: true,
        startDate: start,
        customExcludedDates: excluded,
        weekdayHoursByIndex: weekdayHours,
        dayStart: dayStart,
        dayEnd: dayEnd,
      );
    }

    final range = _dateRangePattern.firstMatch(text);
    if (range == null) return null;
    final start =
        _parseDate(range.group(1)!, range.group(2)!, range.group(3)!);
    final end =
        _parseDate(range.group(4)!, range.group(5)!, range.group(6)!);

    final times = _timePattern.firstMatch(text);
    var dayStart = const TimeOfDay(hour: 9, minute: 0);
    var dayEnd = const TimeOfDay(hour: 18, minute: 0);
    if (times != null && !text.contains('@')) {
      dayStart = _parseTime(times);
      dayEnd = _parseTimeEnd(times);
    }
    final weekdayHours = _parseWeekdayHours(text);
    if (weekdayHours.isNotEmpty) {
      final first = weekdayHours.values.first;
      dayStart = first.start;
      dayEnd = first.end;
    }

    final excluded = <DateTime>{};
    final excludeSection = RegExp(r'제외=([^·]+)').firstMatch(text);
    if (excludeSection != null) {
      for (final part in excludeSection.group(1)!.split(',')) {
        final full = RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})')
            .firstMatch(part.trim());
        if (full != null) {
          excluded.add(_parseDate(
            full.group(1)!,
            full.group(2)!,
            full.group(3)!,
          ));
        }
      }
      return WorkScheduleSpec(
        mode: WorkScheduleMode.customDates,
        startDate: start,
        endDate: end,
        customExcludedDates: excluded,
        weekdayHoursByIndex: weekdayHours,
        dayStart: dayStart,
        dayEnd: dayEnd,
      );
    }

    // 레거시: 명시적 근무일 목록 → 제외일로 변환
    final workDates = <DateTime>{};
    for (final part in text.split(',')) {
      final full = RegExp(r'(\d{4})[./-](\d{1,2})[./-](\d{1,2})')
          .firstMatch(part.trim());
      if (full != null) {
        workDates.add(_parseDate(
          full.group(1)!,
          full.group(2)!,
          full.group(3)!,
        ));
      }
    }
    if (workDates.isNotEmpty) {
      var cursor = start;
      while (!cursor.isAfter(end)) {
        final day = DateTime(cursor.year, cursor.month, cursor.day);
        final isWork = workDates.any(
          (w) => w.year == day.year && w.month == day.month && w.day == day.day,
        );
        if (!isWork) excluded.add(day);
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    return WorkScheduleSpec(
      mode: WorkScheduleMode.customDates,
      startDate: start,
      endDate: end,
      customExcludedDates: excluded,
      weekdayHoursByIndex: weekdayHours,
      dayStart: dayStart,
      dayEnd: dayEnd,
    );
  }

  static List<ShiftSlotKind> _cycleFromLabel(String label) {
    return label.split('').map((ch) {
      return ShiftSlotKind.values.firstWhere(
        (s) => s.shortLabel == ch,
        orElse: () => ShiftSlotKind.off,
      );
    }).toList();
  }

  static DateTime _parseDate(String y, String m, String d) =>
      DateTime(int.parse(y), int.parse(m), int.parse(d));

  static TimeOfDay _parseTime(RegExpMatch match) => TimeOfDay(
        hour: int.parse(match.group(1)!),
        minute: int.parse(match.group(2)!),
      );

  static TimeOfDay _parseTimeEnd(RegExpMatch match) => TimeOfDay(
        hour: int.parse(match.group(3)!),
        minute: int.parse(match.group(4)!),
      );

  static TimeOfDay _parseTimeParts(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _padTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
