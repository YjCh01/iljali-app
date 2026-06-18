import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

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
    required this.appliedAt,
    this.applicationId,
    this.seekerEmail,
    this.employmentType = JobEmploymentType.daily,
    this.genderLabel = '-',
    this.birthDateLabel = '-',
    this.workDate,
    this.workAgreedAt,
    this.phoneMasked,
    this.commissionAmountKrw,
    this.commissionPaid = false,
    this.escalationLevel = 0,
    this.awaitingEmployerConfirm = false,
    this.awaitingSeekerCheckIn = false,
    this.canEmployerConfirm = false,
    this.workAgreementComplete = false,
    this.countdownLabel,
    this.canMarkNoShow = false,
    this.rollCallStatus = TodayRollCallStatus.pending,
  });

  final String id;
  final String? applicationId;
  final String? seekerEmail;
  final JobEmploymentType employmentType;
  final String workerName;
  final String genderLabel;
  final String birthDateLabel;
  final String jobTitle;
  final String workDateLabel;
  final DateTime? workDate;
  final DateTime appliedAt;
  final DateTime? workAgreedAt;
  final String? phoneMasked;
  final String checkInLabel;
  final String checkOutLabel;
  final CorporateAttendanceStatus status;
  final int? commissionAmountKrw;
  final bool commissionPaid;
  final int escalationLevel;
  final bool awaitingEmployerConfirm;
  final bool awaitingSeekerCheckIn;
  final bool canEmployerConfirm;
  final bool workAgreementComplete;
  final String? countdownLabel;
  final bool canMarkNoShow;
  final TodayRollCallStatus rollCallStatus;

  bool get needsCommissionPayment =>
      status == CorporateAttendanceStatus.pendingCommission &&
      !commissionPaid;

  bool get isWorkScheduledToday {
    final date = workDate;
    if (date == null) return false;
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool get isDailyWorker => employmentType == JobEmploymentType.daily;

  bool get isOnDutyToday =>
      isWorkScheduledToday &&
      (rollCallStatus == TodayRollCallStatus.present ||
          rollCallStatus == TodayRollCallStatus.pending);
}

/// 오늘 출근 명단 — 출근/결근/대기
enum TodayRollCallStatus {
  pending,
  present,
  absent,
}

extension TodayRollCallStatusX on TodayRollCallStatus {
  String get label => switch (this) {
        TodayRollCallStatus.pending => '대기',
        TodayRollCallStatus.present => '출근',
        TodayRollCallStatus.absent => '결근',
      };
}

enum CorporateAttendanceStatus {
  onTime,
  late,
  earlyLeave,
  absent,
  pendingCommission,
  awaitingEmployerConfirm,
  awaitingSeekerCheckIn,
}

extension CorporateAttendanceStatusX on CorporateAttendanceStatus {
  String get label => switch (this) {
        CorporateAttendanceStatus.onTime => '정상출근',
        CorporateAttendanceStatus.late => '지각',
        CorporateAttendanceStatus.earlyLeave => '조퇴',
        CorporateAttendanceStatus.absent => '결근',
        CorporateAttendanceStatus.pendingCommission => '수수료 결제 대기',
        CorporateAttendanceStatus.awaitingEmployerConfirm => '기업 확인 대기',
        CorporateAttendanceStatus.awaitingSeekerCheckIn => '구직자 출근 대기',
      };
}
