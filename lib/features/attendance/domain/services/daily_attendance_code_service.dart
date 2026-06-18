import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 기업 일일 출근 QR 코드 (6자리, 로컬 MVP)
class DailyAttendanceCodeService {
  DailyAttendanceCodeService(this._prefs);

  final SharedPreferences _prefs;

  static const _keyPrefix = 'daily_attendance_code_';

  static Future<DailyAttendanceCodeService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return DailyAttendanceCodeService(prefs);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<String> getOrCreateCode({
    required String companyKey,
    DateTime? forDate,
  }) async {
    final date = forDate ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final storageKey = '$_keyPrefix$companyKey';
    final raw = _prefs.getString(storageKey);
    Map<String, dynamic> map = {};
    if (raw != null && raw.isNotEmpty) {
      try {
        map = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
    }

    final dateKey = _dateKey(day);
    final existing = map[dateKey] as String?;
    if (existing != null && existing.length == 6) return existing;

    final code = _generateCode(companyKey, day);
    map[dateKey] = code;
    await _prefs.setString(storageKey, jsonEncode(map));
    return code;
  }

  Future<bool> verifyCode({
    required String companyKey,
    required String code,
    DateTime? forDate,
  }) async {
    final expected = await getOrCreateCode(
      companyKey: companyKey,
      forDate: forDate,
    );
    return expected == code.trim();
  }

  String _generateCode(String companyKey, DateTime day) {
    final seed = companyKey.hashCode ^ day.millisecondsSinceEpoch;
    final n = seed.abs() % 1000000;
    return n.toString().padLeft(6, '0');
  }
}
