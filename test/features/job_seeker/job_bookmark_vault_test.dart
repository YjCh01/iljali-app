import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark.dart';
import 'package:map/features/job_seeker/domain/utils/job_bookmark_retention_policy.dart';
import 'package:map/features/job_seeker/domain/utils/job_bookmark_sort.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JobBookmarkRetentionPolicy', () {
    test('purges bookmarks after 30 days', () {
      final now = DateTime(2026, 5, 30);
      final items = [
        JobBookmark(
          postId: 'old',
          folderId: 'default',
          savedAt: now.subtract(const Duration(days: 31)),
          title: 't',
          companyName: 'c',
          warehouseName: 'w',
          hourlyWage: '10000',
        ),
        JobBookmark(
          postId: 'fresh',
          folderId: 'default',
          savedAt: now.subtract(const Duration(days: 2)),
          title: 't',
          companyName: 'c',
          warehouseName: 'w',
          hourlyWage: '10000',
        ),
      ];
      final kept = JobBookmarkRetentionPolicy.purgeExpired(items, now);
      expect(kept.map((e) => e.postId), ['fresh']);
    });
  });

  group('JobBookmarkSort', () {
    test('sorts by hourly wage descending', () {
      final items = [
        JobBookmark(
          postId: 'a',
          folderId: 'default',
          savedAt: DateTime.now(),
          title: 'a',
          companyName: 'c',
          warehouseName: 'w',
          hourlyWage: '9,860원',
        ),
        JobBookmark(
          postId: 'b',
          folderId: 'default',
          savedAt: DateTime.now(),
          title: 'b',
          companyName: 'c',
          warehouseName: 'w',
          hourlyWage: '12,000원',
        ),
      ];
      final sorted = JobBookmarkSort.sortBookmarks(
        items,
        JobBookmarkSortMode.hourlyWageDesc,
      );
      expect(sorted.first.postId, 'b');
    });
  });

  group('JobBookmarkVaultRepository', () {
    test('saves bookmark and folder', () async {
      SharedPreferences.setMockInitialValues({});
      final repo = await JobBookmarkVaultRepository.create('user@test.com');
      expect(repo, isNotNull);

      final pin = JobMapPin(
        post: CorporateJobPost(
          id: 'post-1',
          title: '야간 분류',
          warehouseName: '물류센터',
          hourlyWage: '11000',
          workSchedule: '야간',
          summary: 's',
          status: CorporateJobPostStatus.recruiting,
          applicantCount: 0,
          postedAt: DateTime(2026, 5, 1),
        ),
        latitude: 37.5,
        longitude: 127.0,
        companyName: '테스트',
        displayTier: JobMapPinDisplayTier.standard,
      );

      final folder = await repo!.createFolder('이번 주');
      final saved = await repo.saveBookmark(pin, folderId: folder.id);
      expect(saved.folderId, folder.id);

      final bookmarks = await repo.loadBookmarks(folderId: folder.id);
      expect(bookmarks, hasLength(1));
      expect(bookmarks.first.postId, 'post-1');

      await repo.updateMemo('post-1', '토요일 지원 예정');
      final withMemo = await repo.loadBookmarks();
      expect(withMemo.first.memo, '토요일 지원 예정');
    });
  });
}
