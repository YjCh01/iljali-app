import 'package:map/features/corporate/domain/entities/work_schedule_spec.dart';

/// 지원 희망 근무일 — ISO 날짜를 쉼표로 연결해 저장
abstract final class SelectedShiftDates {
  static String encode(Iterable<DateTime> dates) {
    final unique = <String, DateTime>{};
    for (final date in dates) {
      final d = _dateOnly(date);
      unique[WorkScheduleSpec.dateKey(d)] = d;
    }
    final sorted = unique.values.toList()..sort();
    return sorted.map(WorkScheduleSpec.dateKey).join(',');
  }

  static List<DateTime> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .map(_parseIso)
        .whereType<DateTime>()
        .toList()
      ..sort();
  }

  static DateTime? primary(String? raw) {
    final list = decode(raw);
    return list.isEmpty ? null : list.first;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime? _parseIso(String iso) {
    final parts = iso.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }
}
