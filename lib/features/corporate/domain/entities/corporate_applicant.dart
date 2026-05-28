/// 지원자 관리용 엔티티
class CorporateApplicant {
  const CorporateApplicant({
    required this.id,
    required this.name,
    required this.jobTitle,
    required this.phoneMasked,
    required this.status,
    required this.appliedAtLabel,
    this.applicationId,
    this.workDateLabel,
    this.seekerEmail,
    this.jobPostId,
  });

  final String id;
  final String name;
  final String jobTitle;
  final String phoneMasked;
  final CorporateApplicantStatus status;
  final String appliedAtLabel;
  final String? applicationId;
  final String? workDateLabel;
  final String? seekerEmail;
  final String? jobPostId;
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
        CorporateApplicantStatus.commissionPaid => '정산완료',
        CorporateApplicantStatus.rejected => '불합격',
      };
}
