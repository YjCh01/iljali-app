import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/hiring_application_status.dart';

export 'hiring_application_status.dart';
import 'package:map/features/attendance/domain/entities/check_in_method.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';

/// 지원·채팅·예정자·출근·수수료까지 이어지는 채용 건
class HiringApplication {
  const HiringApplication({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.companyName,
    required this.seekerEmail,
    required this.seekerName,
    required this.seekerPhoneMasked,
    required this.appliedAt,
    required this.status,
    required this.workSchedule,
    this.employmentType = JobEmploymentType.daily,
    this.workDate,
    this.companyKey,
    this.recruiterEmail,
    this.branchId,
    this.branchName,
    this.workplaceLatitude,
    this.workplaceLongitude,
    this.checkedInAt,
    this.employerConfirmedAt,
    this.mutuallyConfirmedAt,
    this.checkInLatitude,
    this.checkInLongitude,
    this.commissionAmountKrw,
    this.commissionPaidAt,
    this.commissionDueAt,
    this.escalationLevel = 0,
    this.seekerWorkAgreedAt,
    this.employerWorkAgreedAt,
    this.noShowMarkedAt,
    this.agreementCancelledAt,
    this.scheduleChangedAt,
    this.selectedShiftDate,
    this.shiftSlot,
    this.shuttleBookingId,
    this.preferredStopId,
    this.checkedOutAt,
    this.checkInMethod,
    this.seekerClockInVerifiedAt,
    this.employerClockInVerifiedAt,
    this.employerClockInLatitude,
    this.employerClockInLongitude,
    this.geofenceVerified = false,
    this.seekerGeofenceDistanceM,
    this.employerGeofenceDistanceM,
    this.disclosedResumeItems = const [],
    this.requiredCredentialIds = const [],
  });

  final String id;
  final String postId;
  final String postTitle;
  final String companyName;
  final String seekerEmail;
  final String seekerName;
  final String seekerPhoneMasked;
  final DateTime appliedAt;
  final HiringApplicationStatus status;
  final String workSchedule;
  final JobEmploymentType employmentType;
  final DateTime? workDate;
  final String? companyKey;

  /// 공고 등록·출근 확인 담당자 이메일 (결제 위임·라우팅용)
  final String? recruiterEmail;
  final String? branchId;
  final String? branchName;
  final double? workplaceLatitude;
  final double? workplaceLongitude;
  final DateTime? checkedInAt;
  final DateTime? employerConfirmedAt;
  final DateTime? mutuallyConfirmedAt;
  final double? checkInLatitude;
  final double? checkInLongitude;
  final int? commissionAmountKrw;
  final DateTime? commissionPaidAt;
  final DateTime? commissionDueAt;
  final int escalationLevel;
  final DateTime? seekerWorkAgreedAt;
  final DateTime? employerWorkAgreedAt;
  final DateTime? noShowMarkedAt;
  final DateTime? agreementCancelledAt;
  final DateTime? scheduleChangedAt;

  /// 희망 근무일 (ISO yyyy-MM-dd)
  final String? selectedShiftDate;

  /// day | night | any
  final String? shiftSlot;
  final String? shuttleBookingId;
  final String? preferredStopId;
  final DateTime? checkedOutAt;
  final CheckInMethod? checkInMethod;

  /// 구직자 지오펜스 출근 확인 시각
  final DateTime? seekerClockInVerifiedAt;

  /// 기업 지오펜스 출근 확인 시각
  final DateTime? employerClockInVerifiedAt;

  final double? employerClockInLatitude;
  final double? employerClockInLongitude;

  /// 쌍방 지오펜스 검증 완료 (상호 출근 확인 시 true)
  final bool geofenceVerified;

  final double? seekerGeofenceDistanceM;
  final double? employerGeofenceDistanceM;

  /// 지원 시 구직자가 공개 동의한 이력서 항목
  final List<ResumeItemKind> disclosedResumeItems;

  /// 지원 당시 공고 필수 자격증 ID (스냅샷)
  final List<String> requiredCredentialIds;

  bool get isWorkAgreementComplete =>
      seekerWorkAgreedAt != null && employerWorkAgreedAt != null;

  bool get isScheduled =>
      status == HiringApplicationStatus.scheduled ||
      status == HiringApplicationStatus.checkedIn ||
      status == HiringApplicationStatus.commissionPaid;

  bool get seekerCheckedIn => checkedInAt != null;

  bool get employerConfirmed => employerConfirmedAt != null;

  bool get isMutuallyConfirmed =>
      mutuallyConfirmedAt != null &&
      seekerCheckedIn &&
      employerConfirmed;

  /// 지오펜스 요건 충족 (레거시·좌표 없음·완화 환경 포함)
  bool get isGeofenceRequirementMet {
    if (!hasWorkplaceCoordinate) return true;
    if (geofenceVerified) return true;
    // 레거시: 지오펜스 도입 전 상호 확인 건
    if (mutuallyConfirmedAt != null &&
        seekerClockInVerifiedAt == null &&
        employerClockInVerifiedAt == null) {
      return true;
    }
    return seekerClockInVerifiedAt != null &&
        employerClockInVerifiedAt != null;
  }

  bool get awaitingEmployerConfirm =>
      seekerCheckedIn && !employerConfirmed && !isMutuallyConfirmed;

  bool get awaitingSeekerCheckIn =>
      employerConfirmed && !seekerCheckedIn && !isMutuallyConfirmed;

  bool get needsCommissionPayment =>
      employmentType == JobEmploymentType.daily &&
      isMutuallyConfirmed &&
      isGeofenceRequirementMet &&
      status == HiringApplicationStatus.checkedIn &&
      commissionPaidAt == null;

  bool get hasWorkplaceCoordinate =>
      workplaceLatitude != null && workplaceLongitude != null;

  GeoCoordinate? get workplaceCoordinate {
    if (!hasWorkplaceCoordinate) return null;
    return GeoCoordinate(
      latitude: workplaceLatitude!,
      longitude: workplaceLongitude!,
    );
  }

  bool get isPermanentEmployment =>
      employmentType == JobEmploymentType.permanent;

  HiringApplication copyWith({
    String? id,
    String? postTitle,
    String? companyName,
    String? seekerName,
    String? seekerPhoneMasked,
    String? workSchedule,
    HiringApplicationStatus? status,
    DateTime? workDate,
    JobEmploymentType? employmentType,
    String? companyKey,
    String? recruiterEmail,
    String? branchId,
    String? branchName,
    double? workplaceLatitude,
    double? workplaceLongitude,
    DateTime? checkedInAt,
    DateTime? employerConfirmedAt,
    DateTime? mutuallyConfirmedAt,
    double? checkInLatitude,
    double? checkInLongitude,
    int? commissionAmountKrw,
    DateTime? commissionPaidAt,
    DateTime? commissionDueAt,
    int? escalationLevel,
    DateTime? seekerWorkAgreedAt,
    DateTime? employerWorkAgreedAt,
    DateTime? noShowMarkedAt,
    DateTime? agreementCancelledAt,
    DateTime? scheduleChangedAt,
    String? selectedShiftDate,
    String? shiftSlot,
    String? shuttleBookingId,
    String? preferredStopId,
    DateTime? checkedOutAt,
    CheckInMethod? checkInMethod,
    DateTime? seekerClockInVerifiedAt,
    DateTime? employerClockInVerifiedAt,
    double? employerClockInLatitude,
    double? employerClockInLongitude,
    bool? geofenceVerified,
    double? seekerGeofenceDistanceM,
    double? employerGeofenceDistanceM,
    List<ResumeItemKind>? disclosedResumeItems,
    List<String>? requiredCredentialIds,
    bool clearSeekerWorkAgreedAt = false,
    bool clearEmployerWorkAgreedAt = false,
    bool clearNoShowMarkedAt = false,
    bool clearAgreementCancelledAt = false,
    bool clearScheduleChangedAt = false,
  }) {
    return HiringApplication(
      id: id ?? this.id,
      postId: postId,
      postTitle: postTitle ?? this.postTitle,
      companyName: companyName ?? this.companyName,
      seekerEmail: seekerEmail,
      seekerName: seekerName ?? this.seekerName,
      seekerPhoneMasked: seekerPhoneMasked ?? this.seekerPhoneMasked,
      appliedAt: appliedAt,
      status: status ?? this.status,
      workSchedule: workSchedule ?? this.workSchedule,
      employmentType: employmentType ?? this.employmentType,
      workDate: workDate ?? this.workDate,
      companyKey: companyKey ?? this.companyKey,
      recruiterEmail: recruiterEmail ?? this.recruiterEmail,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      workplaceLatitude: workplaceLatitude ?? this.workplaceLatitude,
      workplaceLongitude: workplaceLongitude ?? this.workplaceLongitude,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      employerConfirmedAt: employerConfirmedAt ?? this.employerConfirmedAt,
      mutuallyConfirmedAt: mutuallyConfirmedAt ?? this.mutuallyConfirmedAt,
      checkInLatitude: checkInLatitude ?? this.checkInLatitude,
      checkInLongitude: checkInLongitude ?? this.checkInLongitude,
      commissionAmountKrw: commissionAmountKrw ?? this.commissionAmountKrw,
      commissionPaidAt: commissionPaidAt ?? this.commissionPaidAt,
      commissionDueAt: commissionDueAt ?? this.commissionDueAt,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      seekerWorkAgreedAt: clearSeekerWorkAgreedAt
          ? null
          : (seekerWorkAgreedAt ?? this.seekerWorkAgreedAt),
      employerWorkAgreedAt: clearEmployerWorkAgreedAt
          ? null
          : (employerWorkAgreedAt ?? this.employerWorkAgreedAt),
      noShowMarkedAt:
          clearNoShowMarkedAt ? null : (noShowMarkedAt ?? this.noShowMarkedAt),
      agreementCancelledAt: clearAgreementCancelledAt
          ? null
          : (agreementCancelledAt ?? this.agreementCancelledAt),
      scheduleChangedAt: clearScheduleChangedAt
          ? null
          : (scheduleChangedAt ?? this.scheduleChangedAt),
      selectedShiftDate: selectedShiftDate ?? this.selectedShiftDate,
      shiftSlot: shiftSlot ?? this.shiftSlot,
      shuttleBookingId: shuttleBookingId ?? this.shuttleBookingId,
      preferredStopId: preferredStopId ?? this.preferredStopId,
      checkedOutAt: checkedOutAt ?? this.checkedOutAt,
      checkInMethod: checkInMethod ?? this.checkInMethod,
      seekerClockInVerifiedAt:
          seekerClockInVerifiedAt ?? this.seekerClockInVerifiedAt,
      employerClockInVerifiedAt:
          employerClockInVerifiedAt ?? this.employerClockInVerifiedAt,
      employerClockInLatitude:
          employerClockInLatitude ?? this.employerClockInLatitude,
      employerClockInLongitude:
          employerClockInLongitude ?? this.employerClockInLongitude,
      geofenceVerified: geofenceVerified ?? this.geofenceVerified,
      seekerGeofenceDistanceM:
          seekerGeofenceDistanceM ?? this.seekerGeofenceDistanceM,
      employerGeofenceDistanceM:
          employerGeofenceDistanceM ?? this.employerGeofenceDistanceM,
      disclosedResumeItems:
          disclosedResumeItems ?? this.disclosedResumeItems,
      requiredCredentialIds:
          requiredCredentialIds ?? this.requiredCredentialIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'postTitle': postTitle,
        'companyName': companyName,
        'seekerEmail': seekerEmail,
        'seekerName': seekerName,
        'seekerPhoneMasked': seekerPhoneMasked,
        'appliedAt': appliedAt.toIso8601String(),
        'status': status.name,
        'workSchedule': workSchedule,
        'employmentType': employmentType.name,
        'workDate': workDate?.toIso8601String(),
        'companyKey': companyKey,
        if (recruiterEmail != null) 'recruiterEmail': recruiterEmail,
        'branchId': branchId,
        'branchName': branchName,
        'workplaceLatitude': workplaceLatitude,
        'workplaceLongitude': workplaceLongitude,
        'checkedInAt': checkedInAt?.toIso8601String(),
        'employerConfirmedAt': employerConfirmedAt?.toIso8601String(),
        'mutuallyConfirmedAt': mutuallyConfirmedAt?.toIso8601String(),
        'checkInLatitude': checkInLatitude,
        'checkInLongitude': checkInLongitude,
        'commissionAmountKrw': commissionAmountKrw,
        'commissionPaidAt': commissionPaidAt?.toIso8601String(),
        'commissionDueAt': commissionDueAt?.toIso8601String(),
        'escalationLevel': escalationLevel,
        'seekerWorkAgreedAt': seekerWorkAgreedAt?.toIso8601String(),
        'employerWorkAgreedAt': employerWorkAgreedAt?.toIso8601String(),
        'noShowMarkedAt': noShowMarkedAt?.toIso8601String(),
        'agreementCancelledAt': agreementCancelledAt?.toIso8601String(),
        'scheduleChangedAt': scheduleChangedAt?.toIso8601String(),
        if (selectedShiftDate != null) 'selectedShiftDate': selectedShiftDate,
        if (shiftSlot != null) 'shiftSlot': shiftSlot,
        if (shuttleBookingId != null) 'shuttleBookingId': shuttleBookingId,
        if (preferredStopId != null) 'preferredStopId': preferredStopId,
        'checkedOutAt': checkedOutAt?.toIso8601String(),
        if (checkInMethod != null) 'checkInMethod': checkInMethod!.code,
        'seekerClockInVerifiedAt': seekerClockInVerifiedAt?.toIso8601String(),
        'employerClockInVerifiedAt':
            employerClockInVerifiedAt?.toIso8601String(),
        'employerClockInLatitude': employerClockInLatitude,
        'employerClockInLongitude': employerClockInLongitude,
        'geofenceVerified': geofenceVerified,
        'seekerGeofenceDistanceM': seekerGeofenceDistanceM,
        'employerGeofenceDistanceM': employerGeofenceDistanceM,
        'disclosedResumeItems':
            ResumeItemKindX.encodeList(disclosedResumeItems),
        if (requiredCredentialIds.isNotEmpty)
          'requiredCredentialIds': requiredCredentialIds,
      };

  factory HiringApplication.fromJson(Map<String, dynamic> json) {
    return HiringApplication(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      postTitle: json['postTitle'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String? ?? '',
      seekerName: json['seekerName'] as String? ?? '',
      seekerPhoneMasked: json['seekerPhoneMasked'] as String? ?? '',
      appliedAt: DateTime.tryParse(json['appliedAt'] as String? ?? '') ??
          DateTime.now(),
      status: _parseStatus(json['status'] as String?),
      workSchedule: json['workSchedule'] as String? ?? '',
      employmentType: _parseEmploymentType(json['employmentType'] as String?),
      workDate: DateTime.tryParse(json['workDate'] as String? ?? ''),
      companyKey: json['companyKey'] as String?,
      recruiterEmail: json['recruiterEmail'] as String?,
      branchId: json['branchId'] as String?,
      branchName: json['branchName'] as String?,
      workplaceLatitude: (json['workplaceLatitude'] as num?)?.toDouble(),
      workplaceLongitude: (json['workplaceLongitude'] as num?)?.toDouble(),
      checkedInAt: DateTime.tryParse(json['checkedInAt'] as String? ?? ''),
      employerConfirmedAt:
          DateTime.tryParse(json['employerConfirmedAt'] as String? ?? ''),
      mutuallyConfirmedAt:
          DateTime.tryParse(json['mutuallyConfirmedAt'] as String? ?? ''),
      checkInLatitude: (json['checkInLatitude'] as num?)?.toDouble(),
      checkInLongitude: (json['checkInLongitude'] as num?)?.toDouble(),
      commissionAmountKrw: json['commissionAmountKrw'] as int?,
      commissionPaidAt:
          DateTime.tryParse(json['commissionPaidAt'] as String? ?? ''),
      commissionDueAt: DateTime.tryParse(json['commissionDueAt'] as String? ?? ''),
      escalationLevel: json['escalationLevel'] as int? ?? 0,
      seekerWorkAgreedAt:
          DateTime.tryParse(json['seekerWorkAgreedAt'] as String? ?? ''),
      employerWorkAgreedAt:
          DateTime.tryParse(json['employerWorkAgreedAt'] as String? ?? ''),
      noShowMarkedAt: DateTime.tryParse(json['noShowMarkedAt'] as String? ?? ''),
      agreementCancelledAt:
          DateTime.tryParse(json['agreementCancelledAt'] as String? ?? ''),
      scheduleChangedAt:
          DateTime.tryParse(json['scheduleChangedAt'] as String? ?? ''),
      selectedShiftDate: json['selectedShiftDate'] as String?,
      shiftSlot: json['shiftSlot'] as String?,
      shuttleBookingId: json['shuttleBookingId'] as String?,
      preferredStopId: json['preferredStopId'] as String?,
      checkedOutAt: DateTime.tryParse(json['checkedOutAt'] as String? ?? ''),
      checkInMethod:
          CheckInMethod.fromCode(json['checkInMethod'] as String?),
      seekerClockInVerifiedAt: DateTime.tryParse(
        json['seekerClockInVerifiedAt'] as String? ?? '',
      ),
      employerClockInVerifiedAt: DateTime.tryParse(
        json['employerClockInVerifiedAt'] as String? ?? '',
      ),
      employerClockInLatitude:
          (json['employerClockInLatitude'] as num?)?.toDouble(),
      employerClockInLongitude:
          (json['employerClockInLongitude'] as num?)?.toDouble(),
      geofenceVerified: json['geofenceVerified'] as bool? ?? false,
      seekerGeofenceDistanceM:
          (json['seekerGeofenceDistanceM'] as num?)?.toDouble(),
      employerGeofenceDistanceM:
          (json['employerGeofenceDistanceM'] as num?)?.toDouble(),
      disclosedResumeItems: ResumeItemKindX.parseList(
        json['disclosedResumeItems'] as List<dynamic>?,
      ),
      requiredCredentialIds: (json['requiredCredentialIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  static HiringApplicationStatus _parseStatus(String? raw) {
    if (raw == null || raw.isEmpty) return HiringApplicationStatus.applied;
    try {
      return HiringApplicationStatus.values.byName(raw);
    } on ArgumentError {
      return HiringApplicationStatus.applied;
    }
  }

  static JobEmploymentType _parseEmploymentType(String? raw) {
    if (raw == null || raw.isEmpty) return JobEmploymentType.daily;
    try {
      return JobEmploymentType.values.byName(raw);
    } on ArgumentError {
      return JobEmploymentType.daily;
    }
  }
}
