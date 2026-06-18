import 'dart:convert';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 일일 PUSH 사용·과금 집계 (ROI·한도)
class LocalPushUsageRepository {
  LocalPushUsageRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'push_usage_v1';

  static Future<LocalPushUsageRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalPushUsageRepository(prefs);
  }

  static String dayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  Future<int> getTodayDispatchCount(String companyKey) async {
    final all = await _loadAll();
    final row = all.firstWhere(
      (e) => e.companyKey == companyKey && e.dayKey == dayKey(),
      orElse: () => _PushUsageRow.empty(companyKey, dayKey()),
    );
    return row.dispatchCount;
  }

  Future<ExtraPushQuote?> quoteExtraPushIfNeeded(String companyKey) async {
    return null;
  }

  Future<void> recordDispatch({
    required String companyKey,
    int paymentKrw = 0,
  }) async {
    final all = await _loadAll();
    final key = dayKey();
    final index = all.indexWhere(
      (e) => e.companyKey == companyKey && e.dayKey == key,
    );
    if (index >= 0) {
      final row = all[index];
      all[index] = row.copyWith(
        dispatchCount: row.dispatchCount + 1,
        spendKrw: row.spendKrw + paymentKrw,
      );
    } else {
      all.add(
        _PushUsageRow(
          companyKey: companyKey,
          dayKey: key,
          dispatchCount: 1,
          spendKrw: paymentKrw,
        ),
      );
    }
    await _saveAll(all);
  }

  Future<int> sumSpendSince(String companyKey, DateTime since) async {
    final all = await _loadAll().then(
      (list) => list.where((e) => e.companyKey == companyKey),
    );
    var total = 0;
    for (final row in all) {
      final parsed = DateTime.tryParse('${row.dayKey}T00:00:00');
      if (parsed != null && parsed.isAfter(since.subtract(const Duration(days: 1)))) {
        total += row.spendKrw;
      }
    }
    return total;
  }

  Future<List<_PushUsageRow>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => _PushUsageRow.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> _saveAll(List<_PushUsageRow> rows) async {
    await _prefs.setString(
      _key,
      jsonEncode(rows.map((e) => e.toJson()).toList()),
    );
  }
}

class ExtraPushQuote {
  const ExtraPushQuote({
    required this.amountKrw,
    required this.usedToday,
    required this.dailyLimit,
  });

  final int amountKrw;
  final int usedToday;
  final int dailyLimit;

  String get summaryLine =>
      '기본 일 ${dailyLimit}회 초과 · 지원자 모집하기(add-on) '
      '${amountKrw.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}원/회';
}

class _PushUsageRow {
  const _PushUsageRow({
    required this.companyKey,
    required this.dayKey,
    required this.dispatchCount,
    required this.spendKrw,
  });

  factory _PushUsageRow.empty(String companyKey, String dayKey) =>
      _PushUsageRow(companyKey: companyKey, dayKey: dayKey, dispatchCount: 0, spendKrw: 0);

  factory _PushUsageRow.fromJson(Map<String, dynamic> json) => _PushUsageRow(
        companyKey: json['companyKey'] as String? ?? '',
        dayKey: json['dayKey'] as String? ?? '',
        dispatchCount: json['dispatchCount'] as int? ?? 0,
        spendKrw: json['spendKrw'] as int? ?? 0,
      );

  final String companyKey;
  final String dayKey;
  final int dispatchCount;
  final int spendKrw;

  Map<String, dynamic> toJson() => {
        'companyKey': companyKey,
        'dayKey': dayKey,
        'dispatchCount': dispatchCount,
        'spendKrw': spendKrw,
      };

  _PushUsageRow copyWith({int? dispatchCount, int? spendKrw}) => _PushUsageRow(
        companyKey: companyKey,
        dayKey: dayKey,
        dispatchCount: dispatchCount ?? this.dispatchCount,
        spendKrw: spendKrw ?? this.spendKrw,
      );
}
