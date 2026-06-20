import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/sync/qc_sync_bootstrap.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 로컬 ↔ 서버 동기화 (QC/API URL 설정 시)
class LocalRemoteSyncService {
  LocalRemoteSyncService({IljariApiClient? client})
      : _client = client ?? IljariApiClient();

  final IljariApiClient _client;

  bool get isEnabled =>
      EnvConfig.isComplianceApiEnabled && _client.isEnabled;

  Future<bool> pullFromServer() async {
    if (!isEnabled) return false;
    try {
      await QcSyncBootstrap.pullIfEnabled();
      return true;
    } on Object {
      return false;
    }
  }

  Future<bool> pushLocalChanges() async {
    if (!isEnabled) return false;
    try {
      final posts =
          await const CorporateJobPostLocalDataSourceImpl().fetchJobPosts();
      for (final post in posts) {
        await _client.pushJobPost(_jobPostPayload(post));
      }

      final hiring = await LocalHiringRepository.create();
      for (final app in await hiring.fetchAll()) {
        await _client.pushApplication(_applicationPayload(app));
      }
      return true;
    } on Object {
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> pullJobPosts() async {
    if (!isEnabled) return const [];
    try {
      return await _client.listJobPosts();
    } on Object {
      return const [];
    }
  }

  Future<bool> syncHiringAndChat({
    String? seekerEmail,
    String? companyKey,
  }) async {
    if (!isEnabled) return false;
    try {
      await _client.syncBootstrap(
        seekerEmail: seekerEmail,
        companyKey: companyKey,
      );
      await QcSyncBootstrap.pullIfEnabled();
      return true;
    } on Object {
      return false;
    }
  }

  Map<String, dynamic> _jobPostPayload(CorporateJobPost post) {
    return {
      'id': post.id,
      'title': post.title,
      'company_name': post.registeredBy?.companyName ?? '',
      'company_key': post.registeredBy?.companyKey ?? '',
      'warehouse_name': post.warehouseName,
      'hourly_wage': post.hourlyWage,
      'work_schedule': post.workSchedule,
      'summary': post.summary,
      'status': post.status.name,
    };
  }

  Map<String, dynamic> _applicationPayload(HiringApplication app) {
    return {
      'id': app.id,
      'post_id': app.postId,
      'post_title': app.postTitle,
      'company_name': app.companyName,
      'company_key': app.companyKey ?? '',
      'seeker_email': app.seekerEmail,
      'seeker_name': app.seekerName,
      'status': app.status.name,
      'work_schedule': app.workSchedule,
    };
  }
}
