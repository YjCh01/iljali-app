import 'package:map/features/job_seeker/domain/entities/job_bookmark.dart';

/// 보관함 항목 — 30일 후 자동 삭제 제안
abstract final class JobBookmarkRetentionPolicy {
  static const retentionDays = 30;
  static const expiryWarningDays = 3;

  static bool isExpired(JobBookmark item, [DateTime? now]) {
    final anchor = now ?? DateTime.now();
    return anchor.difference(item.savedAt).inDays >= retentionDays;
  }

  static List<JobBookmark> purgeExpired(
    Iterable<JobBookmark> items, [
    DateTime? now,
  ]) {
    return items.where((item) => !isExpired(item, now)).toList();
  }

  static bool shouldSuggestDeletion(JobBookmark item, [DateTime? now]) {
    final anchor = now ?? DateTime.now();
    final remaining = retentionDays - anchor.difference(item.savedAt).inDays;
    return remaining <= expiryWarningDays && remaining > 0;
  }

  static List<JobBookmark> itemsNeedingDeletionSuggestion(
    Iterable<JobBookmark> items, [
    DateTime? now,
  ]) {
    return items.where((item) => shouldSuggestDeletion(item, now)).toList();
  }

  static DateTime expiresAt(DateTime savedAt) =>
      savedAt.add(const Duration(days: retentionDays));

  static String expiryLabel(DateTime savedAt, [DateTime? now]) {
    final anchor = now ?? DateTime.now();
    final remaining = retentionDays - anchor.difference(savedAt).inDays;
    if (remaining <= 0) return '만료됨';
    if (remaining == 1) return '내일 자동 삭제';
    return '$remaining일 후 자동 삭제';
  }
}
