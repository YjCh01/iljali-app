import 'dart:convert';

import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/commute/domain/entities/seeker_shuttle_route_share_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeekerShuttleRouteShareConsentRepository {
  SeekerShuttleRouteShareConsentRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'seeker_shuttle_route_share_consent_v1';

  static Future<SeekerShuttleRouteShareConsentRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerShuttleRouteShareConsentRepository(prefs);
  }

  Future<List<SeekerShuttleRouteShareConsent>> fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => SeekerShuttleRouteShareConsent.fromJson(e.cast()))
        .toList();
  }

  Future<List<SeekerShuttleRouteShareConsent>> fetchForSeeker(String email) async {
    final normalized = email.trim().toLowerCase();
    return (await fetchAll())
        .where((c) => c.seekerEmail.trim().toLowerCase() == normalized)
        .toList();
  }

  Future<SeekerShuttleRouteShareConsent?> findForCompany({
    required String seekerEmail,
    required String companyKey,
  }) async {
    final key =
        '${seekerEmail.trim().toLowerCase()}|${companyKey.trim()}';
    for (final row in await fetchForSeeker(seekerEmail)) {
      if (row.storageKey == key) return row;
    }
    return null;
  }

  Future<SeekerShuttleRouteShareConsent> save(
    SeekerShuttleRouteShareConsent consent,
  ) async {
    final all = await fetchAll();
    final index = all.indexWhere((c) => c.storageKey == consent.storageKey);
    if (index >= 0) {
      all[index] = consent;
    } else {
      all.add(consent);
    }
    await _prefs.setString(
      _key,
      jsonEncode(all.map((c) => c.toJson()).toList()),
    );
    return consent;
  }

  Future<void> syncToServer(SeekerShuttleRouteShareConsent consent) async {
    if (!EnvConfig.isComplianceApiEnabled) return;
    final client = IljariApiClient();
    if (!client.isEnabled) return;
    try {
      await client.upsertShuttleRouteShareConsent(
        companyKey: consent.companyKey,
        optedIn: consent.optedIn,
        towerParticipationConsented: consent.towerParticipationConsented,
      );
    } on Object {
      // 로컬 유지
    }
  }

  Future<List<SeekerShuttleRouteShareConsent>> fetchMergedForSeeker(
    String email,
  ) async {
    final local = await fetchForSeeker(email);
    if (!EnvConfig.isComplianceApiEnabled) return local;
    final client = IljariApiClient();
    if (!client.isEnabled) return local;
    try {
      final remote = await client.fetchShuttleRouteShareConsents();
      final byKey = {for (final c in local) c.storageKey: c};
      for (final row in remote) {
        final companyKey = row['company_key'] as String? ?? '';
        if (companyKey.isEmpty) continue;
        final key = '${email.trim().toLowerCase()}|$companyKey';
        byKey[key] = SeekerShuttleRouteShareConsent(
          seekerEmail: email.trim().toLowerCase(),
          companyKey: companyKey,
          companyName: row['company_name'] as String? ?? '',
          optedIn: row['opted_in'] as bool? ?? false,
          towerParticipationOffered: row['offered_at'] != null,
          towerParticipationConsented:
              row['tower_participation_consented'] as bool? ?? false,
          offerPending: row['offered_at'] != null &&
              !(row['opted_in'] as bool? ?? false) &&
              !(row['tower_participation_consented'] as bool? ?? false),
          applicationId: row['application_id'] as String?,
          updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
              DateTime.now(),
        );
      }
      final merged = byKey.values.toList();
      await _prefs.setString(
        _key,
        jsonEncode([
          ... (await fetchAll()).where(
            (c) => c.seekerEmail.trim().toLowerCase() != email.trim().toLowerCase(),
          ),
          ...merged.map((c) => c.toJson()),
        ]),
      );
      return merged;
    } on Object {
      return local;
    }
  }
}
