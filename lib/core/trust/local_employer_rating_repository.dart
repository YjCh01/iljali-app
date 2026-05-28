import 'dart:convert';

import 'package:map/core/trust/employer_rating.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalEmployerRatingRepository {
  LocalEmployerRatingRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'employer_ratings_v1';

  static Future<LocalEmployerRatingRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LocalEmployerRatingRepository(prefs);
  }

  Future<void> save(EmployerRating rating) async {
    final all = await _loadAll();
    all.removeWhere((r) => r.applicationId == rating.applicationId);
    all.insert(0, rating);
    await _prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
  }

  Future<bool> hasRated(String applicationId) async {
    final all = await _loadAll();
    return all.any((r) => r.applicationId == applicationId);
  }

  Future<EmployerRatingSummary> summarizeCompany(String companyKey) async {
    final all =
        await _loadAll().then((list) => list.where((r) => r.companyKey == companyKey));
    if (all.isEmpty) {
      return const EmployerRatingSummary(
        averageStars: 0,
        reviewCount: 0,
        topTags: [],
      );
    }
    final avg = all.map((r) => r.stars).reduce((a, b) => a + b) / all.length;
    final tagCounts = <String, int>{};
    for (final r in all) {
      for (final tag in r.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return EmployerRatingSummary(
      averageStars: avg,
      reviewCount: all.length,
      topTags: topTags.take(3).map((e) => e.key).toList(),
    );
  }

  Future<List<EmployerRating>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => EmployerRating.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
