import 'package:map/core/admin/admin_ops_api_client.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/sync/job_post_sync_service.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';

/// 어드민 — 근무지·본사 불일치 공고 승인 (서버 API + 로컬 동기화)
abstract final class WorkplaceMismatchAdminService {
  static Future<String?> approveStatedWorkplacePost({
    required String flagId,
    AdminOpsApiClient? adminClient,
  }) async {
    final admin = adminClient ?? AdminOpsApiClient();
    Map<String, dynamic>? apiResult;

    if (admin.isEnabled) {
      final parsedId = int.tryParse(flagId);
      if (parsedId != null) {
        try {
          apiResult = await admin.approveStatedWorkplacePost(parsedId);
        } on IljariApiException catch (e) {
          return e.message;
        } on Object {
          return '서버 승인 처리에 실패했습니다.';
        }
      }
    }

    final postId = apiResult?['post_id'] as String? ??
        (await _postIdFromLocalFlag(flagId));
    if (postId == null || postId.isEmpty) {
      if (apiResult != null) return null;
      return '연결된 공고 ID가 없습니다.';
    }

    await _publishLocalPost(postId);

    if (!admin.isEnabled || apiResult == null) {
      final compliance = await ComplianceRepository.create();
      final flag = await compliance.findAbuseFlagById(flagId);
      if (flag == null && apiResult == null) {
        return '검토 항목을 찾을 수 없습니다.';
      }
      if (flag != null) {
        await compliance.updateAbuseFlagById(flagId, {
          'reviewStatus': 'approved',
          'resolvedAt': DateTime.now().toIso8601String(),
          'resolvedAction': 'publish_stated_workplace',
        });
      }
    } else {
      await _resolveLocalFlagIfExists(flagId, postId);
    }

    return null;
  }

  static Future<String?> _postIdFromLocalFlag(String flagId) async {
    final compliance = await ComplianceRepository.create();
    final flag = await compliance.findAbuseFlagById(flagId);
    return flag?['postId'] as String?;
  }

  static Future<void> _resolveLocalFlagIfExists(
    String flagId,
    String postId,
  ) async {
    final compliance = await ComplianceRepository.create();
    final flag = await compliance.findAbuseFlagById(flagId);
    if (flag != null) {
      await compliance.updateAbuseFlagById(flagId, {
        'reviewStatus': 'approved',
        'resolvedAt': DateTime.now().toIso8601String(),
        'resolvedAction': 'publish_stated_workplace',
      });
      return;
    }
    for (final f in await compliance.fetchAbuseFlags()) {
      if (f['type'] == 'workplaceMismatch' &&
          f['postId'] == postId &&
          (f['reviewStatus'] as String? ?? 'pending') == 'pending') {
        await compliance.updateAbuseFlagById('${f['id']}', {
          'reviewStatus': 'approved',
          'resolvedAt': DateTime.now().toIso8601String(),
          'resolvedAction': 'publish_stated_workplace',
        });
        return;
      }
    }
  }

  static Future<void> _publishLocalPost(String postId) async {
    const postSource = CorporateJobPostLocalDataSourceImpl();
    final post = await postSource.findById(postId);
    if (post == null) return;

    final now = DateTime.now();
    final published = post.copyWith(
      status: CorporateJobPostStatus.recruiting,
      postedAt: now,
      expiresAt: JobPostValidity.expiresAtFromRegistration(now),
    );

    await postSource.updateJobPost(published);
    await JobPostSyncService().pushPostUpdate(published);
  }
}
