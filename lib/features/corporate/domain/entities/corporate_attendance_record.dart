/// 근태 관리용 엔티티
class CorporateAttendanceRecord {
  const CorporateAttendanceRecord({
    required this.id,
    required this.workerName,
    required this.jobTitle,
    required this.workDateLabel,
    required this.checkInLabel,
    required this.checkOutLabel,
    required this.status,
    this.applicationId,
    this.commissionAmountKrw,
    this.commissionPaid = false,
    this.escalationLevel = 0,
  });

  final String id;
  final String? applicationId;
  final String workerName;
  final String jobTitle;
  final String workDateLabel;
  final String checkInLabel;
  final String checkOutLabel;
  final CorporateAttendanceStatus status;
  final int? commissionAmountKrw;
  final bool commissionPaid;
  final int escalationLevel;

  bool get needsCommissionPayment =>
      status == CorporateAttendanceStatus.pendingCommission &&
      !commissionPaid;
}

enum CorporateAttendanceStatus {
  onTime,
  late,
  earlyLeave,
  absent,
  pendingCommission,
}

extension CorporateAttendanceStatusX on CorporateAttendanceStatus {
  String get label => switch (this) {
        CorporateAttendanceStatus.onTime => '정상출근',
        CorporateAttendanceStatus.late => '지각',
        CorporateAttendanceStatus.earlyLeave => '조퇴',
        CorporateAttendanceStatus.absent => '결근',
        CorporateAttendanceStatus.pendingCommission => '수수료 결제 대기',
      };
}
