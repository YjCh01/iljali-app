import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/data/repositories/job_bookmark_vault_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_bookmark_folder.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('JobBookmarkVaultRepository folder ops', () {
    late JobBookmarkVaultRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repo = (await JobBookmarkVaultRepository.create('folder@test.com'))!;
    });

    JobMapPin testPin(String id) => JobMapPin(
          post: CorporateJobPost(
            id: id,
            title: '공고 $id',
            warehouseName: '창고',
            hourlyWage: '10,000원',
            workSchedule: '09-18',
            summary: 's',
            status: CorporateJobPostStatus.recruiting,
            applicantCount: 0,
            postedAt: DateTime(2026, 1, 1),
          ),
          companyName: '테스트',
          latitude: 37.0,
          longitude: 127.0,
          displayTier: JobMapPinDisplayTier.standard,
        );

    test('renameFolder updates folder name', () async {
      final folder = await repo.createFolder('주말');
      await repo.renameFolder(folder.id, '이번 주말');
      final folders = await repo.loadFolders();
      expect(
        folders.firstWhere((f) => f.id == folder.id).name,
        '이번 주말',
      );
    });

    test('deleteFolder moves bookmarks to default', () async {
      final folder = await repo.createFolder('삭제용');
      await repo.saveBookmark(testPin('p1'), folderId: folder.id);
      await repo.saveBookmark(testPin('p2'), folderId: folder.id);
      await repo.deleteFolder(folder.id);

      final folders = await repo.loadFolders();
      expect(folders.any((f) => f.id == folder.id), isFalse);

      final bookmarks = await repo.loadBookmarks();
      expect(bookmarks.every((b) => b.folderId == JobBookmarkFolder.defaultFolderId), isTrue);
      expect(bookmarks.map((b) => b.postId), containsAll(['p1', 'p2']));
    });

    test('cannot delete default folder', () async {
      expect(
        () => repo.deleteFolder(JobBookmarkFolder.defaultFolderId),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
