import 'package:map/core/compliance/contact_entitlement.dart';
import 'package:map/core/compliance/data/compliance_api_client.dart';
import 'package:map/core/compliance/data/compliance_repository.dart';
import 'package:map/core/config/env_config.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 지원자 연락·채팅 — 기본 플랜 포함 (티어 차단 없음)
class ContactEntitlementService {
  ContactEntitlementService({
    ComplianceRepository? repository,
    ComplianceApiClient? apiClient,
  })  : _repository = repository,
        _apiClient = apiClient ?? ComplianceApiClient();

  ComplianceRepository? _repository;
  final ComplianceApiClient _apiClient;

  Future<ComplianceRepository> _repo() async =>
      _repository ??= await ComplianceRepository.create();

  ContactAccessResult evaluate(CorporateMemberProfile profile) {
    if (profile.isSuspended) {
      return ContactAccessResult.blocked(
        reason: '계정이 정지되었습니다. 고객센터에 문의해 주세요.',
      );
    }
    if (profile.verificationStatus.name == 'suspended' ||
        profile.verificationStatus.name == 'rejected') {
      return ContactAccessResult.blocked(
        reason: '사업자 검증 상태로 인해 연락 기능을 사용할 수 없습니다.',
      );
    }
    if (profile.requiresAdminReview && !profile.adminReviewApproved) {
      return ContactAccessResult.blocked(
        reason: profile.adminReviewReason ??
            '관리자 검토 중입니다. 승인 후 연락 기능이 활성화됩니다.',
        upsell: false,
      );
    }
    return ContactAccessResult.allowedFull;
  }

  Future<ContactAccessResult> evaluateWithUsage(
    CorporateMemberProfile profile,
  ) async {
    if (EnvConfig.isComplianceApiEnabled && _apiClient.isEnabled) {
      try {
        return await _apiClient.fetchContactEntitlement(profile.companyKey);
      } on Object {
        // 로컬 fallback
      }
    }
    return evaluate(profile);
  }

  Future<ContactAccessResult> recordContactAttempt(
    CorporateMemberProfile profile, {
    required String applicationId,
    required String action,
  }) async {
    if (EnvConfig.isComplianceApiEnabled && _apiClient.isEnabled) {
      try {
        final remote = await _apiClient.recordContactEvent(
          companyKey: profile.companyKey,
          applicationId: applicationId,
          action: action,
          tier: 'default',
        );
        return remote;
      } on Object {
        // fallback
      }
    }

    final access = evaluate(profile);
    final repo = await _repo();
    await repo.logContactEvent({
      'companyKey': profile.companyKey,
      'applicationId': applicationId,
      'action': action,
      'tier': 'default',
      'allowed': access.allowed,
    });

    return access;
  }
}
