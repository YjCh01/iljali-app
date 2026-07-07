import 'package:map/core/sync/job_post_sync_service.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';

class DeleteCorporateJobPostResult {
  const DeleteCorporateJobPostResult({
    required this.deletedLocally,
    required this.syncedToServer,
  });

  final bool deletedLocally;
  final bool syncedToServer;

  bool get isSuccess => deletedLocally;
}

/// 공고 삭제 — 로컬 제거 후 서버 동기화
class DeleteCorporateJobPostUseCase {
  const DeleteCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<DeleteCorporateJobPostResult> call({
    required String postId,
    String? ownerCompanyKey,
  }) async {
    final deleted = await _dataSource.deleteJobPost(
      postId,
      ownerCompanyKey: ownerCompanyKey,
    );
    if (!deleted) {
      return const DeleteCorporateJobPostResult(
        deletedLocally: false,
        syncedToServer: false,
      );
    }
    final synced = await JobPostSyncService().pushDelete(postId);
    return DeleteCorporateJobPostResult(
      deletedLocally: true,
      syncedToServer: synced,
    );
  }
}
