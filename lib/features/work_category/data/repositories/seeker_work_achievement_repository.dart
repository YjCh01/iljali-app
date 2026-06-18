import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:map/features/work_category/domain/entities/seeker_work_achievement.dart';
import 'package:map/features/work_category/domain/entities/work_category_catalog.dart';

/// 구직자 업무 업적 영속화
class SeekerWorkAchievementRepository {
  SeekerWorkAchievementRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _countsPrefix = 'seeker_work_achievement_counts_';
  static const _awardedPrefix = 'seeker_work_achievement_awarded_';

  static Future<SeekerWorkAchievementRepository> create() async {
    final prefs = await SharedPreferences.getInstance();
    return SeekerWorkAchievementRepository(prefs);
  }

  Future<SeekerWorkAchievementSummary> loadSummary(String seekerEmail) async {
    final counts = _loadCounts(seekerEmail);
    final entries = WorkCategoryCatalog.all
        .map(
          (def) => SeekerWorkAchievementEntry(
            categoryId: def.id,
            count: counts[def.id] ?? 0,
          ),
        )
        .toList();
    final total = counts.values.fold<int>(0, (sum, n) => sum + n);
    return SeekerWorkAchievementSummary(
      seekerEmail: seekerEmail,
      entries: entries,
      totalCompletions: total,
    );
  }

  Future<bool> hasAwardedApplication({
    required String seekerEmail,
    required String applicationId,
  }) async {
    final set = _loadAwardedSet(seekerEmail);
    return set.contains(applicationId);
  }

  Future<SeekerWorkAchievementEntry?> awardOnce({
    required String seekerEmail,
    required String applicationId,
    required String categoryId,
  }) async {
    final awarded = _loadAwardedSet(seekerEmail);
    if (awarded.contains(applicationId)) return null;

    awarded.add(applicationId);
    await _prefs.setStringList(
      '$_awardedPrefix$seekerEmail',
      awarded.toList(),
    );

    final counts = _loadCounts(seekerEmail);
    final next = (counts[categoryId] ?? 0) + 1;
    counts[categoryId] = next;
    await _prefs.setString(
      '$_countsPrefix$seekerEmail',
      jsonEncode(counts),
    );

    return SeekerWorkAchievementEntry(
      categoryId: categoryId,
      count: next,
      lastAwardedAt: DateTime.now(),
    );
  }

  Map<String, int> _loadCounts(String seekerEmail) {
    final raw = _prefs.getString('$_countsPrefix$seekerEmail');
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      );
    } on Object {
      return {};
    }
  }

  Set<String> _loadAwardedSet(String seekerEmail) {
    final list = _prefs.getStringList('$_awardedPrefix$seekerEmail');
    return list?.toSet() ?? {};
  }
}
