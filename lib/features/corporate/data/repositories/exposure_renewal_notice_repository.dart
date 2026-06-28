import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 노출 만료 연장 알림 — 공고별 1회 발송 기록
class ExposureRenewalNoticeRepository {
  ExposureRenewalNoticeRepository(this._prefs);

  static const _keyPrefix = 'exposure_renewal_notice_v1_';

  final SharedPreferences _prefs;

  static Future<ExposureRenewalNoticeRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ExposureRenewalNoticeRepository(prefs);
  }

  String _key(String companyKey) => '$_keyPrefix$companyKey';

  Future<Set<String>> loadDismissedPostIds(String companyKey) async {
    final raw = _prefs.getString(_key(companyKey));
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => '$e').toSet();
    } catch (_) {
      return {};
    }
  }

  Future<void> markDismissed({
    required String companyKey,
    required String jobPostId,
  }) async {
    final set = await loadDismissedPostIds(companyKey);
    set.add(jobPostId);
    await _prefs.setString(_key(companyKey), jsonEncode(set.toList()));
  }

  Future<void> clearDismissed({
    required String companyKey,
    required String jobPostId,
  }) async {
    final set = await loadDismissedPostIds(companyKey);
    set.remove(jobPostId);
    await _prefs.setString(_key(companyKey), jsonEncode(set.toList()));
  }
}
