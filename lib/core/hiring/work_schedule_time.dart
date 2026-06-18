/// 공고·합의에 포함된 근무 시각 파싱 (MVP)
abstract final class WorkScheduleTime {
  static const checkGraceAfterEnd = Duration(hours: 2);

  /// `09:00–18:00`, `09:00-18:00`, `09:00~18:00` 등에서 종료 시각
  static (int hour, int minute)? parseEndClock(String workSchedule) {
    final match = RegExp(r'(\d{1,2}):(\d{2})\s*$').firstMatch(workSchedule.trim());
    if (match == null) {
      final range = RegExp(
        r'(\d{1,2}):(\d{2})\s*[~\-–]\s*(\d{1,2}):(\d{2})',
      ).firstMatch(workSchedule);
      if (range == null) return null;
      return (int.parse(range.group(3)!), int.parse(range.group(4)!));
    }
    return (int.parse(match.group(1)!), int.parse(match.group(2)!));
  }

  static (int hour, int minute)? parseStartClock(String workSchedule) {
    final range = RegExp(
      r'(\d{1,2}):(\d{2})\s*[~\-–]\s*(\d{1,2}):(\d{2})',
    ).firstMatch(workSchedule);
    if (range == null) return null;
    return (int.parse(range.group(1)!), int.parse(range.group(2)!));
  }

  static DateTime? workStartAt(DateTime workDate, String workSchedule) {
    final clock = parseStartClock(workSchedule);
    if (clock == null) return null;
    return DateTime(workDate.year, workDate.month, workDate.day, clock.$1, clock.$2);
  }

  static DateTime? workEndAt(DateTime workDate, String workSchedule) {
    final clock = parseEndClock(workSchedule);
    if (clock == null) return null;
    return DateTime(workDate.year, workDate.month, workDate.day, clock.$1, clock.$2);
  }

  static DateTime? checkWindowClosesAt(DateTime workDate, String workSchedule) {
    final end = workEndAt(workDate, workSchedule);
    return end?.add(checkGraceAfterEnd);
  }

  /// 출근까지 남은 시간 — `1일 9h 45m`
  static String? countdownLabel({
    required DateTime? workDate,
    required String workSchedule,
    DateTime? now,
  }) {
    if (workDate == null) return null;
    final start = workStartAt(workDate, workSchedule);
    if (start == null) return null;
    final current = now ?? DateTime.now();
    if (!current.isBefore(start)) return null;
    return _formatDuration(start.difference(current));
  }

  static String _formatDuration(Duration d) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    if (days > 0) return '${days}일 ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }
}
