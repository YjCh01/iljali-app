import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';

/// 수신 푸시 보관 — 30일 후 자동 삭제
abstract final class SeekerPushRetentionPolicy {
  static const retentionDays = 30;

  static bool isExpired(SeekerPushNotification item, [DateTime? now]) {
    final anchor = now ?? DateTime.now();
    return anchor.difference(item.receivedAt).inDays >= retentionDays;
  }

  static List<SeekerPushNotification> purgeExpired(
    Iterable<SeekerPushNotification> items, [
    DateTime? now,
  ]) {
    return items.where((item) => !isExpired(item, now)).toList();
  }

  static DateTime expiresAt(DateTime receivedAt) =>
      receivedAt.add(const Duration(days: retentionDays));

  static String expiryLabel(DateTime receivedAt) {
    final remaining =
        retentionDays - DateTime.now().difference(receivedAt).inDays;
    if (remaining <= 0) return '만료됨';
    if (remaining == 1) return '내일 자동 삭제';
    return '$remaining일 후 자동 삭제';
  }
}
