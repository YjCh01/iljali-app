import 'dart:convert';

import 'package:map/features/commute/domain/entities/seeker_commute_tower_consent.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SeekerCommuteTowerConsentRepository {
  SeekerCommuteTowerConsentRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _key = 'seeker_commute_tower_consent_v1';

  static Future<SeekerCommuteTowerConsentRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerCommuteTowerConsentRepository(prefs);
  }

  Future<List<SeekerCommuteTowerConsent>> fetchAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => SeekerCommuteTowerConsent.fromJson(e.cast()))
        .toList();
  }

  Future<SeekerCommuteTowerConsent?> findForRoute({
    required String seekerEmail,
    required String companyKey,
    required String routeId,
  }) async {
    final key =
        '${seekerEmail.trim().toLowerCase()}|${companyKey.trim()}|${routeId.trim()}';
    for (final row in await fetchAll()) {
      if (row.storageKey == key) return row;
    }
    return null;
  }

  Future<List<SeekerCommuteTowerConsent>> fetchForSeeker(String email) async {
    final normalized = email.trim().toLowerCase();
    return (await fetchAll())
        .where((c) => c.seekerEmail.trim().toLowerCase() == normalized)
        .toList();
  }

  Future<SeekerCommuteTowerConsent> save(SeekerCommuteTowerConsent consent) async {
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
}
