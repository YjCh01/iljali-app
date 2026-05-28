import 'dart:convert';

import 'package:map/core/config/env_config.dart';
import 'package:map/core/metrics/data/metrics_api_client.dart';
import 'package:map/core/trust/company_rating.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 구직자가 남긴 고용주 평가 저장
class LocalCompanyRatingRepository {
  LocalCompanyRatingRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'company_ratings_by_seekers_v1';

  static Future<LocalCompanyRatingRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalCompanyRatingRepository(prefs);
    await repo._purgePersistedDemoRatings();
    return repo;
  }

  Future<void> save(CompanyRating rating) async {
    final all = await _loadAll();
    all.removeWhere((r) => r.applicationId == rating.applicationId);
    all.insert(0, rating);
    await _prefs.setString(
      _key,
      jsonEncode(all.map((e) => e.toJson()).toList()),
    );
    if (EnvConfig.isComplianceApiEnabled) {
      try {
        await MetricsApiClient().submitCompanyRating(rating);
      } on MetricsApiException {
        // 로컬 우선 — API 실패 시에도 앱 사용 가능
      }
    }
  }

  Future<bool> hasRated(String applicationId) async {
    final all = await _loadAll();
    return all.any((r) => r.applicationId == applicationId);
  }

  Future<CompanyRatingSummary> summarizeCompany(String companyKey) async {
    final all = (await _loadAll())
        .where((r) => r.companyKey == companyKey)
        .toList();
    if (all.isNotEmpty) {
      return _summaryFromRatings(all);
    }
    if (EnvConfig.isComplianceApiEnabled) {
      try {
        return await MetricsApiClient().fetchCompanyRatingSummary(companyKey);
      } on MetricsApiException {
        // fall through to empty
      }
    }
    return const CompanyRatingSummary(
      averageStars: 0,
      reviewCount: 0,
      topTags: [],
    );
  }

  CompanyRatingSummary _summaryFromRatings(List<CompanyRating> all) {
    final avg = all.map((r) => r.stars).reduce((a, b) => a + b) / all.length;
    final tagCounts = <String, int>{};
    for (final r in all) {
      for (final tag in r.tags) {
        tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
      }
    }
    final topTags = tagCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return CompanyRatingSummary(
      averageStars: avg,
      reviewCount: all.length,
      topTags: topTags.take(3).map((e) => e.key).toList(),
    );
  }

  Future<void> _purgePersistedDemoRatings() async {
    final all = await _loadAll();
    final cleaned = all.where((r) => !r.id.startsWith('demo_')).toList();
    if (cleaned.length == all.length) return;
    await _prefs.setString(
      _key,
      jsonEncode(cleaned.map((r) => r.toJson()).toList()),
    );
  }

  Future<List<CompanyRating>> _loadAll() async {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((e) => CompanyRating.fromJson(e.cast<String, dynamic>()))
        .toList();
  }
}
