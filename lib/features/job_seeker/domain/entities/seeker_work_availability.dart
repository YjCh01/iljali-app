import 'dart:convert';

/// 구직자 근무 가능 시간 — 요일별 슬롯 (MVP)
class SeekerAvailabilitySlot {
  const SeekerAvailabilitySlot({
    required this.weekday,
    this.startMinutes,
    this.endMinutes,
    this.anyTime = false,
  });

  /// 0=월 … 6=일
  final int weekday;
  final int? startMinutes;
  final int? endMinutes;
  final bool anyTime;

  static const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  String get weekdayLabel => weekdayLabels[weekday.clamp(0, 6)];

  String get displayLabel {
    if (anyTime) return '$weekdayLabel · 시간 무관';
    final start = startMinutes;
    final end = endMinutes;
    if (start == null || end == null) return weekdayLabel;
    return '$weekdayLabel · ${formatMinutes(start)}–${formatMinutes(end)}';
  }

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'weekday': weekday,
        if (startMinutes != null) 'startMinutes': startMinutes,
        if (endMinutes != null) 'endMinutes': endMinutes,
        'anyTime': anyTime,
      };

  factory SeekerAvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return SeekerAvailabilitySlot(
      weekday: json['weekday'] as int? ?? 0,
      startMinutes: json['startMinutes'] as int?,
      endMinutes: json['endMinutes'] as int?,
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
          anyTime == other.anyTime;

  @override
  int get hashCode => Object.hash(weekday, startMinutes, endMinutes, anyTime);
}

class SeekerWorkAvailability {
  const SeekerWorkAvailability({this.slots = const []});

  final List<SeekerAvailabilitySlot> slots;

  bool get isEmpty => slots.isEmpty;

  String encode() => jsonEncode(slots.map((s) => s.toJson()).toList());

  static SeekerWorkAvailability decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const SeekerWorkAvailability();
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return SeekerWorkAvailability(
        slots: list
            .map((e) => SeekerAvailabilitySlot.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on Object {
      return const SeekerWorkAvailability();
    }
  }

  SeekerWorkAvailability copyWith({List<SeekerAvailabilitySlot>? slots}) {
    return SeekerWorkAvailability(slots: slots ?? this.slots);
  }

  /// 같은 요일·시간대 중복 제거 후 추가
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
