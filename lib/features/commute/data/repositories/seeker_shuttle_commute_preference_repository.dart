import 'dart:convert';

import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_commute_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자 통근 정류장 선택 — 서버 원본 + 로컬 캐시
class SeekerShuttleCommutePreferenceRepository {
  SeekerShuttleCommutePreferenceRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'seeker_shuttle_prefs_cache_v1';

  static Future<SeekerShuttleCommutePreferenceRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerShuttleCommutePreferenceRepository(prefs);
  }

  bool get _useRemote =>
      EnvConfig.isComplianceApiEnabled && IljariApiClient().isEnabled;

  Future<List<SeekerShuttleCommutePreference>> fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => SeekerShuttleCommutePreference.fromJson(e.cast()))
        .toList();
  }

  Future<List<SeekerShuttleCommutePreference>> fetchForSeeker(
    String email,
  ) async {
    final normalized = email.trim().toLowerCase();
    if (_useRemote) {
      try {
        final client = IljariApiClient();
        final remote = await client.fetchShuttlePreferences();
        final prefs = remote
            .map(_preferenceFromServerRow)
            .where((p) => p.seekerEmail == normalized)
            .toList();
        await _mergeCacheForSeeker(normalized, prefs);
        return prefs;
      } on Object {
        // 캐시 폴백
      }
    }
    return (await fetchAll())
        .where((p) => p.seekerEmail.trim().toLowerCase() == normalized)
        .toList();
  }

  SeekerShuttleCommutePreference _preferenceFromServerRow(
    Map<String, dynamic> row,
  ) {
    return SeekerShuttleCommutePreference(
      seekerEmail: row['seeker_email'] as String? ?? '',
      companyKey: row['company_key'] as String? ?? '',
      companyName: row['company_name'] as String? ?? '',
      routeId: row['route_id'] as String? ?? '',
      routeName: row['route_name'] as String? ?? '',
      stopId: row['stop_id'] as String? ?? '',
      stopLabel: row['stop_label'] as String? ?? '',
      pickupTime: row['pickup_time'] as String? ?? '',
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Future<void> _mergeCacheForSeeker(
    String seekerEmail,
    List<SeekerShuttleCommutePreference> prefs,
  ) async {
    final all = await fetchAll();
    final next = [
      ...all.where((p) => p.seekerEmail.trim().toLowerCase() != seekerEmail),
      ...prefs,
    ];
    await _prefs.setString(
      _key,
      jsonEncode(next.map((p) => p.toJson()).toList()),
    );
  }

  Future<SeekerShuttleCommutePreference?> findForCompany({
    required String seekerEmail,
    required String companyKey,
  }) async {
    for (final pref in await fetchForSeeker(seekerEmail)) {
      if (pref.companyKey == companyKey.trim()) return pref;
    }
    return null;
  }

  Future<SeekerShuttleCommutePreference?> findForRoute({
    required String seekerEmail,
    required String companyKey,
    required String routeId,
  }) async {
    final pref = await findForCompany(
      seekerEmail: seekerEmail,
      companyKey: companyKey,
    );
    if (pref != null && pref.routeId == routeId.trim()) return pref;
    return null;
  }

  Future<SeekerShuttleCommutePreference> save(
    SeekerShuttleCommutePreference preference,
  ) async {
    if (_useRemote) {
      try {
        await IljariApiClient().upsertShuttlePreference(
          companyKey: preference.companyKey,
          companyName: preference.companyName,
          routeId: preference.routeId,
          routeName: preference.routeName,
          stopId: preference.stopId,
          stopLabel: preference.stopLabel,
          pickupTime: preference.pickupTime,
        );
      } on Object {
        // 로컬은 저장
      }
    }
    final all = await fetchAll();
    final seeker = preference.seekerEmail.trim().toLowerCase();
    final company = preference.companyKey.trim();
    all.removeWhere(
      (p) =>
          p.seekerEmail.trim().toLowerCase() == seeker &&
          p.companyKey.trim() == company,
    );
    all.add(preference);
    await _prefs.setString(
      _key,
      jsonEncode(all.map((p) => p.toJson()).toList()),
    );
    return preference;
  }

  Future<void> removeForCompany({
    required String seekerEmail,
    required String companyKey,
  }) async {
    if (_useRemote) {
      try {
        await IljariApiClient().deleteShuttlePreference(companyKey);
      } on Object {
        // 로컬 삭제는 진행
      }
    }
    final seeker = seekerEmail.trim().toLowerCase();
    final company = companyKey.trim();
    final all = await fetchAll();
    final next = all
        .where(
          (p) =>
              !(p.seekerEmail.trim().toLowerCase() == seeker &&
                  p.companyKey.trim() == company),
        )
        .toList();
    if (next.length == all.length) return;
    await _prefs.setString(
      _key,
      jsonEncode(next.map((p) => p.toJson()).toList()),
    );
  }

  Future<void> removeForRoute({
    required String seekerEmail,
    required String companyKey,
    required String routeId,
  }) async {
    final pref = await findForRoute(
      seekerEmail: seekerEmail,
      companyKey: companyKey,
      routeId: routeId,
    );
    if (pref == null) return;
    await removeForCompany(seekerEmail: seekerEmail, companyKey: companyKey);
  }
}
