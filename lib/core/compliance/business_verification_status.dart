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
        BusinessVerificationStatus.pending => '미인증',
        BusinessVerificationStatus.verified => '검증 완료',
        BusinessVerificationStatus.adminReviewRequired => '등록증 검토',
        BusinessVerificationStatus.suspended => '이용 정지',
        BusinessVerificationStatus.rejected => '승인 거부',
      };

  /// 무료 공고·기본 플랫폼 이용 (유료 결제는 [CorporateVerificationAccessPolicy] 참고)
  bool get canUsePlatform => switch (this) {
        BusinessVerificationStatus.pending ||
        BusinessVerificationStatus.verified ||
        BusinessVerificationStatus.adminReviewRequired =>
          true,
        _ => false,
      };
}
