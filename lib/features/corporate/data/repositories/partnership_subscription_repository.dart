import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

/// 파트너십 구독 이력 (기업별)
class PartnershipSubscriptionRepository {
  PartnershipSubscriptionRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'partnership_subscriptions_v1';

  static Future<PartnershipSubscriptionRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return PartnershipSubscriptionRepository(prefs);
  }

  Future<void> save({
    required String companyKey,
    required PremiumPartnershipTier tier,
    required int amountKrw,
    required String transactionId,
  }) async {
    final all = await _loadAll();
    all.insert(0, {
      'companyKey': companyKey,
      'tier': tier.name,
      'amountKrw': '$amountKrw',
      'transactionId': transactionId,
      'subscribedAt': DateTime.now().toIso8601String(),
    });
    if (all.length > 100) all.removeRange(100, all.length);
    await _prefs.setString(_key, jsonEncode(all));
  }

  Future<List<Map<String, String>>> fetchForCompany(String companyKey) async {
    final all = await _loadAll();
    return all
        .where((row) => row['companyKey'] == companyKey)
        .map((row) => row.map((k, v) => MapEntry(k, v ?? '')))
        .toList();
  }

  Future<List<Map<String, String>>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => item.map((k, v) => MapEntry('$k', '$v')))
        .toList();
  }
}
