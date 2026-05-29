import 'package:flutter_test/flutter_test.dart';

import 'package:map/features/job_seeker/domain/entities/seeker_push_notification.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_push_retention_policy.dart';

void main() {
  test('isExpired after 30 days', () {
    final received = DateTime(2026, 1, 1);
    expect(
      SeekerPushRetentionPolicy.isExpired(
        SeekerPushNotification(
          id: '1',
          title: 't',
          body: 'b',
          companyName: 'c',
          receivedAt: received,
        ),
        DateTime(2026, 1, 31),
      ),
      isTrue,
    );
    expect(
      SeekerPushRetentionPolicy.isExpired(
        SeekerPushNotification(
          id: '1',
          title: 't',
          body: 'b',
          companyName: 'c',
          receivedAt: received,
        ),
        DateTime(2026, 1, 30, 23, 59),
      ),
      isFalse,
    );
  });

  test('purgeExpired removes old items', () {
    final now = DateTime(2026, 5, 29);
    final items = [
      SeekerPushNotification(
        id: 'old',
        title: 't',
        body: 'b',
        companyName: 'c',
        receivedAt: now.subtract(const Duration(days: 31)),
      ),
      SeekerPushNotification(
        id: 'fresh',
        title: 't',
        body: 'b',
        companyName: 'c',
        receivedAt: now.subtract(const Duration(days: 2)),
      ),
    ];
    final kept = SeekerPushRetentionPolicy.purgeExpired(items, now);
    expect(kept.map((e) => e.id), ['fresh']);
  });
}
