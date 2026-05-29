import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

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

  bool get isScheduled =>
      status == HiringApplicationStatus.scheduled ||
      status == HiringApplicationStatus.checkedIn ||
      status == HiringApplicationStatus.commissionPaid;

  bool get seekerCheckedIn => checkedInAt != null;

  bool get employerConfirmed => employerConfirmedAt != null;

  bool get isMutuallyConfirmed =>
      mutuallyConfirmedAt != null ||
      (status == HiringApplicationStatus.checkedIn && checkedInAt != null);

  bool get awaitingEmployerConfirm =>
      seekerCheckedIn && !employerConfirmed && !isMutuallyConfirmed;

  bool get awaitingSeekerCheckIn =>
      employerConfirmed && !seekerCheckedIn && !isMutuallyConfirmed;

  bool get needsCommissionPayment =>
      employmentType == JobEmploymentType.daily &&
      isMutuallyConfirmed &&
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
    HiringApplicationStatus? status,
    DateTime? workDate,
    JobEmploymentType? employmentType,
    String? companyKey,
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
  }) {
    return HiringApplication(
      id: id,
      postId: postId,
      postTitle: postTitle,
      companyName: companyName,
      seekerEmail: seekerEmail,
      seekerName: seekerName,
      seekerPhoneMasked: seekerPhoneMasked,
      appliedAt: appliedAt,
      status: status ?? this.status,
      workSchedule: workSchedule,
      employmentType: employmentType ?? this.employmentType,
      workDate: workDate ?? this.workDate,
      companyKey: companyKey ?? this.companyKey,
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
      status: HiringApplicationStatus.values.byName(
        json['status'] as String? ?? HiringApplicationStatus.applied.name,
      ),
      workSchedule: json['workSchedule'] as String? ?? '',
      employmentType: JobEmploymentType.values.byName(
        json['employmentType'] as String? ?? JobEmploymentType.daily.name,
      ),
      workDate: DateTime.tryParse(json['workDate'] as String? ?? ''),
      companyKey: json['companyKey'] as String?,
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
    );
  }
}
