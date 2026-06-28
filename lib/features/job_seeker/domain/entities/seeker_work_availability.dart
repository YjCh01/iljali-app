import 'dart:convert';

/// 구직자 근무 가능 시간 — 요일별 슬롯 (야간·익일 종료 지원)
class SeekerAvailabilitySlot {
  const SeekerAvailabilitySlot({
    required this.weekday,
    this.startMinutes,
    this.endMinutes,
    this.endDayOffset = 0,
    this.anyTime = false,
  });

  /// 0=월 … 6=일
  final int weekday;
  final int? startMinutes;
  final int? endMinutes;

  /// 종료 시각이 다음날이면 1 (예: 금 21:00 → 토 07:00)
  final int endDayOffset;
  final bool anyTime;

  static const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String get weekdayLabel => weekdayLabels[weekday.clamp(0, 6)];

  bool get spansOvernight => !anyTime && endDayOffset > 0;

  String get endWeekdayLabel {
    if (!spansOvernight) return weekdayLabel;
    return weekdayLabels[(weekday + endDayOffset) % 7];
  }

  String get displayLabel {
    if (anyTime) return '$weekdayLabel · 시간 무관';
    final start = startMinutes;
    final end = endMinutes;
    if (start == null || end == null) return weekdayLabel;
    final endPart = spansOvernight
        ? '${formatMinutes(end)} ($endWeekdayLabel)'
        : formatMinutes(end);
    return '$weekdayLabel · ${formatMinutes(start)}–$endPart';
  }

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static int? parseTimeOption(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || (m != 0 && m != 30)) {
      return null;
    }
    return h * 60 + m;
  }

  static List<String> get halfHourTimeOptions {
    final options = <String>[];
    for (var minutes = 0; minutes < 24 * 60; minutes += 30) {
      options.add(formatMinutes(minutes));
    }
    return options;
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        if (startMinutes != null) 'startMinutes': startMinutes,
        if (endMinutes != null) 'endMinutes': endMinutes,
        if (endDayOffset > 0) 'endDayOffset': endDayOffset,
        'anyTime': anyTime,
      };

  factory SeekerAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return SeekerAvailabilitySlot(
      weekday: json['weekday'] as int? ?? 0,
      startMinutes: json['startMinutes'] as int?,
      endMinutes: json['endMinutes'] as int?,
      endDayOffset: json['endDayOffset'] as int? ?? 0,
      anyTime: json['anyTime'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SeekerAvailabilitySlot &&
          weekday == other.weekday &&
          startMinutes == other.startMinutes &&
          endMinutes == other.endMinutes &&
          endDayOffset == other.endDayOffset &&
          anyTime == other.anyTime;

  @override
  int get hashCode =>
      Object.hash(weekday, startMinutes, endMinutes, endDayOffset, anyTime);
}

class SeekerWorkAvailability {
  const SeekerWorkAvailability({this.slots = const []});

  final List<SeekerAvailabilitySlot> slots;

  bool get isEmpty => slots.isEmpty;

  List<Map<String, dynamic>> toJsonList() =>
      slots.map((s) => s.toJson()).toList();

  String encode() => jsonEncode(toJsonList());

  static SeekerWorkAvailability decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SeekerWorkAvailability();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const SeekerWorkAvailability();
      return SeekerWorkAvailability(
        slots: decoded
            .whereType<Map>()
            .map((e) => SeekerAvailabilitySlot.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
    } on Object {
      return const SeekerWorkAvailability();
    }
  }

  static SeekerWorkAvailability fromJsonList(dynamic raw) {
    if (raw is List) {
      return SeekerWorkAvailability(
        slots: raw
            .whereType<Map>()
            .map((e) => SeekerAvailabilitySlot.fromJson(e.cast<String, dynamic>()))
            .toList(),
      );
    }
    if (raw is String) return decode(raw);
    return const SeekerWorkAvailability();
  }

  SeekerWorkAvailability copyWith({List<SeekerAvailabilitySlot>? slots}) {
    return SeekerWorkAvailability(slots: slots ?? this.slots);
  }

  SeekerWorkAvailability withSlots(Iterable<SeekerAvailabilitySlot> added) {
    final merged = [...slots];
    for (final slot in added) {
      merged.removeWhere((s) => s == slot);
      merged.add(slot);
    }
    merged.sort((a, b) {
      final byDay = a.weekday.compareTo(b.weekday);
      if (byDay != 0) return byDay;
      if (a.anyTime && !b.anyTime) return -1;
      if (!a.anyTime && b.anyTime) return 1;
      return (a.startMinutes ?? 0).compareTo(b.startMinutes ?? 0);
    });
    return copyWith(slots: merged);
  }

  SeekerWorkAvailability withoutSlot(SeekerAvailabilitySlot slot) {
    return copyWith(slots: slots.where((s) => s != slot).toList());
  }

  List<SeekerAvailabilitySlot> slotsForWeekday(int weekday) =>
      slots.where((s) => s.weekday == weekday).toList();
}
