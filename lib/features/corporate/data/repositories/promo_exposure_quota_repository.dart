import 'dart:convert';

import 'package:map/core/config/free_exposure_launch_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 프로모션 기간 회사당 월별 무료 노출 활성화 횟수
class PromoExposureQuotaRepository {
  PromoExposureQuotaRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'promo_exposure_quota_v1';

  static Future<PromoExposureQuotaRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PromoExposureQuotaRepository(prefs);
  }

  static String monthKey([DateTime? clock]) {
    final now = clock ?? DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  Future<int> usedThisMonth(String companyKey, [DateTime? clock]) {
    final key = companyKey.trim();
    if (key.isEmpty) return Future.value(0);
    final month = monthKey(clock);
    final all = _loadAll();
    final company = all[key];
    if (company == null) return Future.value(0);
    return Future.value(company[month] as int? ?? 0);
  }

  Future<int> remainingThisMonth(String companyKey, [DateTime? clock]) async {
    final used = await usedThisMonth(companyKey, clock);
    return (FreeExposureLaunchPolicy.monthlyActivationCapPerCompany - used)
        .clamp(0, FreeExposureLaunchPolicy.monthlyActivationCapPerCompany);
  }

  /// [count]회 사용 가능하면 기록 후 true
  Future<bool> tryConsume(String companyKey, int count, [DateTime? clock]) async {
    final key = companyKey.trim();
    if (key.isEmpty || count <= 0) return false;

    final month = monthKey(clock);
    final all = _loadAll();
    final company = Map<String, dynamic>.from(all[key] ?? {});
    final used = company[month] as int? ?? 0;
    final cap = FreeExposureLaunchPolicy.monthlyActivationCapPerCompany;
    if (used + count > cap) return false;

    company[month] = used + count;
    all[key] = company;
    await _prefs.setString(_key, jsonEncode(all));
    return true;
  }

  Map<String, Map<String, dynamic>> _loadAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};
    return decoded.map(
      (k, v) => MapEntry(
        '$k',
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{},
      ),
    );
  }
}
