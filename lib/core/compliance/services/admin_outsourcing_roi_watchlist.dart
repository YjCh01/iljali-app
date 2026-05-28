import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 관리자가 「아웃소싱 대비 절감」 리포트를 볼 협력사(기업) 목록
abstract final class AdminOutsourcingRoiWatchlist {
  static const _key = 'admin_outsourcing_roi_watchlist_v1';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw);
    if (decoded is! List) return {};
    return decoded.whereType<String>().toSet();
  }

  static Future<void> save(Set<String> companyKeys) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(companyKeys.toList()));
  }

  static Future<bool> toggle(String companyKey, bool enabled) async {
    final set = await load();
    if (enabled) {
      set.add(companyKey);
    } else {
      set.remove(companyKey);
    }
    await save(set);
    return enabled;
  }

  static Future<bool> isEnabled(String companyKey) async {
    final set = await load();
    return set.contains(companyKey);
  }
}
