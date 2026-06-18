import 'package:map/features/work_category/domain/entities/work_category_catalog.dart';
import 'package:map/features/work_category/domain/entities/work_category_definition.dart';

/// 구직자 업무 업적 1건
class SeekerWorkAchievementEntry {
  const SeekerWorkAchievementEntry({
    required this.categoryId,
    required this.count,
    this.lastAwardedAt,
  });

  final String categoryId;
  final int count;
  final DateTime? lastAwardedAt;

  WorkCategoryDefinition? get definition =>
      WorkCategoryCatalog.findById(categoryId);

  SeekerWorkAchievementEntry copyWith({
    int? count,
    DateTime? lastAwardedAt,
  }) {
    return SeekerWorkAchievementEntry(
      categoryId: categoryId,
      count: count ?? this.count,
      lastAwardedAt: lastAwardedAt ?? this.lastAwardedAt,
    );
  }
}

/// 구직자 전체 업적 요약
class SeekerWorkAchievementSummary {
  const SeekerWorkAchievementSummary({
    required this.seekerEmail,
    required this.entries,
    required this.totalCompletions,
  });

  final String seekerEmail;
  final List<SeekerWorkAchievementEntry> entries;
  final int totalCompletions;

  List<SeekerWorkAchievementEntry> get earnedEntries =>
      entries.where((e) => e.count > 0).toList()
        ..sort((a, b) => b.count.compareTo(a.count));

  int countFor(String categoryId) {
    for (final entry in entries) {
      if (entry.categoryId == categoryId) return entry.count;
    }
    return 0;
  }
}
