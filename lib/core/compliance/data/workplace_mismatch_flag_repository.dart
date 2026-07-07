import 'package:map/core/admin/admin_ops_api_client.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/config/env_config.dart';

/// API ↔ 로컬 플래그 필드 매핑
abstract final class WorkplaceMismatchFlagMapper {
  static Map<String, dynamic> fromApi(Map<String, dynamic> flag) {
    return {
      'id': '${flag['id']}',
      'companyKey': flag['company_key'] ?? '',
      'companyName': flag['company_name'] ?? '',
      'postId': flag['post_id'] ?? '',
      'postTitle': flag['post_title'] ?? '',
      'headOfficeAddress': flag['head_office_address'] ?? '',
      'workplaceAddress': flag['workplace_address'] ?? '',
      'distanceMeters': flag['distance_meters'],
      'reviewStatus': flag['review_status'] ?? 'pending',
      'message': flag['message'] ?? '',
    };
  }
}

/// 근무지·본사 불일치 플래그 — 서버 우선, 오프라인 시 로컬
abstract final class WorkplaceMismatchFlagRepository {
  static Future<List<Map<String, dynamic>>> fetchPending({
    AdminOpsApiClient? adminClient,
  }) async {
    final admin = adminClient ?? AdminOpsApiClient();
    if (admin.isEnabled) {
      try {
        final flags = await admin.listWorkplaceMismatchPending();
        return flags.map(WorkplaceMismatchFlagMapper.fromApi).toList();
      } on Object {
        // fall through to local
      }
    }
    final repo = await ComplianceRepository.create();
    return repo.fetchWorkplaceMismatchPendingFlags();
  }

  static Future<void> report({
    required String companyKey,
    required String headOfficeAddress,
    required String workplaceAddress,
    String? reason,
    int? distanceMeters,
    String? companyName,
    String? postId,
    String? postTitle,
    IljariApiClient? apiClient,
  }) async {
    final api = apiClient ?? IljariApiClient();
    if (EnvConfig.isComplianceApiEnabled && api.isEnabled) {
      try {
        await api.reportWorkplaceMismatch(
          companyKey: companyKey,
          companyName: companyName ?? '',
          headOfficeAddress: headOfficeAddress,
          workplaceAddress: workplaceAddress,
          postId: postId ?? '',
          postTitle: postTitle ?? '',
          distanceMeters: distanceMeters,
          reason: reason,
        );
        return;
      } on Object {
        // offline — local fallback
      }
    }

    final repo = await ComplianceRepository.create();
    if (postId != null && postId.isNotEmpty) {
      final existing = await repo.fetchAbuseFlags();
      final duplicate = existing.any(
        (f) =>
            f['type'] == 'workplaceMismatch' &&
            f['postId'] == postId &&
            (f['reviewStatus'] as String? ?? 'pending') == 'pending',
      );
      if (duplicate) return;
    }
    await repo.addAbuseFlag({
      'type': 'workplaceMismatch',
      'severity': 'high',
      'companyKey': companyKey,
      'companyName': companyName ?? '',
      'headOfficeAddress': headOfficeAddress,
      'workplaceAddress': workplaceAddress,
      if (postId != null) 'postId': postId,
      if (postTitle != null) 'postTitle': postTitle,
      if (distanceMeters != null) 'distanceMeters': distanceMeters,
      'reviewStatus': 'pending',
      'message': reason ?? '실근무지와 사업자 소재지 불일치 — 어드민 검토 대상',
    });
  }
}
