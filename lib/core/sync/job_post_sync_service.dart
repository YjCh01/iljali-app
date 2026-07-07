import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 공고 생성·수정 시 서버 DB 영속화
class JobPostSyncService {
  JobPostSyncService({IljariApiClient? client})
      : _client = client ?? IljariApiClient();

  final IljariApiClient _client;

  bool get isEnabled =>
      EnvConfig.isComplianceApiEnabled && _client.isEnabled;

  Future<void> pushPost(CorporateJobPost post) async {
    if (!isEnabled) return;
    try {
      final user = AuthSession.instance.currentUser;
      await _client.createJobPost({
        'id': post.id,
        'title': post.title,
        'company_name': post.registeredBy?.companyName ?? '',
        'company_key': post.registeredBy?.companyKey ?? '',
        'warehouse_name': post.warehouseName,
        'hourly_wage': post.hourlyWage,
        'work_schedule': post.workSchedule,
        'summary': post.summary,
        'job_description': post.jobDescription,
        'description_body_json': post.descriptionBody.toJsonString(),
        'workplace_latitude': _workplaceLatitude(post),
        'workplace_longitude': _workplaceLongitude(post),
        'status': post.status.name,
        'posted_by_email': user?.email ?? post.recruiterEmail ?? '',
        'posted_by_name': user?.name ??
            post.registeredBy?.contactPersonName ??
            '',
      });
    } on Object {
      // 로컬 등록은 유지 — 서버 실패는 비차단
    }
  }

  Future<void> pushPostUpdate(CorporateJobPost post) async {
    if (!isEnabled) return;
    try {
      await _client.updateJobPost(post.id, {
        'title': post.title,
        'company_name': post.registeredBy?.companyName ?? '',
        'warehouse_name': post.warehouseName,
        'hourly_wage': post.hourlyWage,
        'work_schedule': post.workSchedule,
        'summary': post.summary,
        'job_description': post.jobDescription,
        'description_body_json': post.descriptionBody.toJsonString(),
        'workplace_latitude': _workplaceLatitude(post),
        'workplace_longitude': _workplaceLongitude(post),
        'status': post.status.name,
      });
    } on Object {
      // non-blocking
    }
  }

  /// 공고 삭제 — 서버 DB에서 제거 (재시작 시 bootstrap 부활 방지)
  Future<bool> pushDelete(String postId) async {
    if (!isEnabled) return true;
    try {
      await _client.deleteJobPost(postId);
      return true;
    } on Object {
      return false;
    }
  }

  double? _workplaceLatitude(CorporateJobPost post) {
    final stored = post.workplaceCoordinate;
    if (stored != null) return stored.latitude;
    final settings = post.notificationSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      return settings.basePoints.first.coordinate.latitude;
    }
    return null;
  }

  double? _workplaceLongitude(CorporateJobPost post) {
    final stored = post.workplaceCoordinate;
    if (stored != null) return stored.longitude;
    final settings = post.notificationSettings;
    if (settings != null && settings.basePoints.isNotEmpty) {
      return settings.basePoints.first.coordinate.longitude;
    }
    return null;
  }
}
