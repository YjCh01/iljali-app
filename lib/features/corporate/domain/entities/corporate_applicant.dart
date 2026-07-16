import 'package:map/core/config/product_feature_flags.dart';

/// 지원자 관리용 엔티티
class CorporateApplicant {
  const CorporateApplicant({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.phoneMasked,
    required this.status,
    required this.appliedAtLabel,
    required this.appliedAt,
    this.applicationId,
    this.workDateLabel,
    this.seekerEmail,
    this.jobPostId,
    this.companyCheckInCount = 0,
    this.applicationAttempt = 1,
    this.noShowCount = 0,
  });

  final String id;
  final String name;
  final String jobTitle;
  final String phoneMasked;
  final CorporateApplicantStatus status;
  final String appliedAtLabel;
  final DateTime appliedAt;
  final String? applicationId;
  final String? workDateLabel;
  final String? seekerEmail;
  final String? jobPostId;

  /// 이 기업 공고에서의 누적 출근(확인·정산) 횟수
  final int companyCheckInCount;

  /// 이 기업에 몇 번째 지원인지 (1차, 2차, …)
  final int applicationAttempt;

  /// 서버 누적 노쇼 횟수 — 다른 기업이 마킹한 것도 포함.
  final int noShowCount;
}

enum CorporateApplicantStatus {
  pending,
  chatting,
  scheduled,
  checkedIn,
  commissionPaid,
  rejected,
}

extension CorporateApplicantStatusX on CorporateApplicantStatus {
  String get label => switch (this) {
        CorporateApplicantStatus.pending => '검토중',
        CorporateApplicantStatus.chatting => '채팅중',
        CorporateApplicantStatus.scheduled => '출근 예정',
        CorporateApplicantStatus.checkedIn => '출근완료',
        CorporateApplicantStatus.commissionPaid =>
          ProductFeatureFlags.isHiringCommissionEnabled ? '정산완료' : '채용완료',
        CorporateApplicantStatus.rejected => '불합격',
      };
}
