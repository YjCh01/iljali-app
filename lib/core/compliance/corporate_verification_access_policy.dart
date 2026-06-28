import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 기업회원 검증 단계별 기능 — 미인증(무료 공고) vs 검증 완료(유료)
class CorporateVerificationAccessPolicy {
  const CorporateVerificationAccessPolicy._();

  /// 무료 공고 등록·700m 기본 노출
  static bool canPostFreeJobs(CorporateMemberProfile profile) {
    if (profile.isSuspended) return false;
    return switch (profile.verificationStatus) {
      BusinessVerificationStatus.pending ||
      BusinessVerificationStatus.verified ||
      BusinessVerificationStatus.adminReviewRequired =>
        true,
      BusinessVerificationStatus.suspended ||
      BusinessVerificationStatus.rejected =>
        false,
    };
  }

  /// 알림핀·패키지 결제·유료 노출 활성화
  static bool canUsePaidServices(CorporateMemberProfile profile) {
    if (profile.isSuspended) return false;
    if (profile.verificationStatus == BusinessVerificationStatus.suspended ||
        profile.verificationStatus == BusinessVerificationStatus.rejected) {
      return false;
    }
    if (profile.verificationStatus == BusinessVerificationStatus.pending) {
      return false;
    }
    if (profile.requiresAdminReview && !profile.adminReviewApproved) {
      return false;
    }
    return profile.verificationStatus == BusinessVerificationStatus.verified ||
        profile.verificationStatus == BusinessVerificationStatus.adminReviewRequired;
  }

  static bool isProvisionalMember(CorporateMemberProfile profile) =>
      profile.verificationStatus == BusinessVerificationStatus.pending;

  static bool isAwaitingCertificateReview(CorporateMemberProfile profile) =>
      profile.verificationStatus ==
          BusinessVerificationStatus.adminReviewRequired &&
      profile.requiresAdminReview &&
      !profile.adminReviewApproved;

  static String? paidServicesBlockedReason(CorporateMemberProfile profile) {
    if (canUsePaidServices(profile)) return null;
    if (profile.isSuspended ||
        profile.verificationStatus == BusinessVerificationStatus.suspended) {
      return '계정이 정지되어 유료 서비스를 이용할 수 없습니다.';
    }
    if (profile.verificationStatus == BusinessVerificationStatus.rejected) {
      return '사업자 승인이 거부되어 유료 서비스를 이용할 수 없습니다.';
    }
    if (isProvisionalMember(profile)) {
      return '미인증 회원은 무료 공고만 이용할 수 있습니다. '
          '사업자등록증을 제출·승인받으면 알림핀·유료 노출을 이용할 수 있습니다.';
    }
    if (isAwaitingCertificateReview(profile)) {
      return '사업자등록증 검토 중입니다. 승인 후 유료 서비스를 이용할 수 있습니다.';
    }
    if (profile.requiresAdminReview && !profile.adminReviewApproved) {
      return profile.adminReviewReason ??
          '관리자 검토 완료 후 유료 서비스를 이용할 수 있습니다.';
    }
    return '사업자 검증 후 유료 서비스를 이용할 수 있습니다.';
  }
}
