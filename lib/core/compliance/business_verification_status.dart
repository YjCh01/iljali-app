/// 사업자 검증 상태
enum BusinessVerificationStatus {
  pending,
  verified,
  adminReviewRequired,
  suspended,
  rejected,
}

extension BusinessVerificationStatusX on BusinessVerificationStatus {
  String get label => switch (this) {
        BusinessVerificationStatus.pending => '검증 대기',
        BusinessVerificationStatus.verified => '검증 완료',
        BusinessVerificationStatus.adminReviewRequired => '관리자 검토',
        BusinessVerificationStatus.suspended => '이용 정지',
        BusinessVerificationStatus.rejected => '승인 거부',
      };

  bool get canUsePlatform => switch (this) {
        BusinessVerificationStatus.verified => true,
        BusinessVerificationStatus.adminReviewRequired => true,
        _ => false,
      };
}
