import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 채용 공고 고용 형태 — 일용직(출근 확인) · 상시직(재직 확인)
enum JobEmploymentType {
  daily,
  permanent,
}

extension JobEmploymentTypeX on JobEmploymentType {
  String get label => switch (this) {
        JobEmploymentType.daily => '일용직',
        JobEmploymentType.permanent => '상시직',
      };

  bool get isPermanent => this == JobEmploymentType.permanent;
}

/// 기업회원 공고 관리용 채용 공고
class CorporateJobPost {
  const CorporateJobPost({
    required this.id,
    required this.title,
    required this.warehouseName,
    required this.hourlyWage,
    required this.workSchedule,
    required this.summary,
    this.jobDescription = '',
    required this.status,
    required this.applicantCount,
    required this.postedAt,
    this.employmentType = JobEmploymentType.daily,
    this.workerCategory,
    this.dailyWage,
    this.paymentDate,
    this.paymentMonthOffset,
    this.paymentDayOfMonth,
    this.notificationSettings,
    this.registeredBy,
    this.paymentRecord,
    this.branchId,
    this.branchName,
    this.mapPinDisplayTier,
  });

  final String id;
  final String title;
  final JobEmploymentType employmentType;

  /// 공고 고용 유형 (일반 · 일용직 · 계약직). 구버전은 null → [effectiveWorkerCategory]
  final WorkerCategory? workerCategory;

  /// 근무지 표시명 (도로명 주소 또는 센터명)
  final String warehouseName;
  final String hourlyWage;
  final String? dailyWage;
  final String workSchedule;
  final String summary;

  /// 업무 내용 (요약·추가 내용과 분리)
  final String jobDescription;
  final DateTime? paymentDate;

  /// null이면 [paymentDate] 절대일 모드 (일용직)
  final SalaryPaymentMonthOffset? paymentMonthOffset;
  final int? paymentDayOfMonth;

  final JobPostNotificationSettings? notificationSettings;
  final CorporateMemberProfile? registeredBy;
  final JobPostPaymentRecord? paymentRecord;
  final String? branchId;
  final String? branchName;

  /// 등록 시점 지도 핀 등급
  final JobMapPinDisplayTier? mapPinDisplayTier;

  final CorporateJobPostStatus status;
  final int applicantCount;
  final DateTime postedAt;

  CorporateJobPost copyWith({
    String? title,
    JobEmploymentType? employmentType,
    WorkerCategory? workerCategory,
    String? warehouseName,
    String? hourlyWage,
    String? dailyWage,
    String? workSchedule,
    String? summary,
    String? jobDescription,
    DateTime? paymentDate,
    SalaryPaymentMonthOffset? paymentMonthOffset,
    int? paymentDayOfMonth,
    JobPostNotificationSettings? notificationSettings,
    CorporateMemberProfile? registeredBy,
    JobPostPaymentRecord? paymentRecord,
    String? branchId,
    String? branchName,
    JobMapPinDisplayTier? mapPinDisplayTier,
    CorporateJobPostStatus? status,
    int? applicantCount,
    DateTime? postedAt,
  }) {
    return CorporateJobPost(
      id: id,
      title: title ?? this.title,
      employmentType: employmentType ?? this.employmentType,
      workerCategory: workerCategory ?? this.workerCategory,
      warehouseName: warehouseName ?? this.warehouseName,
      hourlyWage: hourlyWage ?? this.hourlyWage,
      dailyWage: dailyWage ?? this.dailyWage,
      workSchedule: workSchedule ?? this.workSchedule,
      summary: summary ?? this.summary,
      jobDescription: jobDescription ?? this.jobDescription,
      paymentDate: paymentDate ?? this.paymentDate,
      paymentMonthOffset: paymentMonthOffset ?? this.paymentMonthOffset,
      paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,
      notificationSettings: notificationSettings ?? this.notificationSettings,
      registeredBy: registeredBy ?? this.registeredBy,
      paymentRecord: paymentRecord ?? this.paymentRecord,
      branchId: branchId ?? this.branchId,
      branchName: branchName ?? this.branchName,
      mapPinDisplayTier: mapPinDisplayTier ?? this.mapPinDisplayTier,
      status: status ?? this.status,
      applicantCount: applicantCount ?? this.applicantCount,
      postedAt: postedAt ?? this.postedAt,
    );
  }
}

enum CorporateJobPostStatus {
  recruiting,
  closingSoon,
  closed,
}

extension CorporateJobPostWorkerCategoryX on CorporateJobPost {
  WorkerCategory get effectiveWorkerCategory {
    if (workerCategory != null) return workerCategory!;
    if (employmentType == JobEmploymentType.permanent) {
      return WorkerCategory.contract;
    }
    if (paymentMonthOffset != null && paymentDayOfMonth != null) {
      return WorkerCategory.general;
    }
    if (paymentDate != null) return WorkerCategory.daily;
    return WorkerCategory.general;
  }
}

extension CorporateJobPostPaymentScheduleX on CorporateJobPost {
  SalaryPaymentSchedule? get paymentSchedule =>
      salaryPaymentScheduleFromPost(this);

  String? get paymentScheduleDisplayLabel => paymentSchedule?.displayLabel;

  bool get hasCompletePaymentSchedule =>
      paymentSchedule?.isComplete ?? false;
}

extension CorporateJobPostMapPinX on CorporateJobPost {
  JobMapPinDisplayTier get effectiveMapPinTier =>
      MapPinTierResolver.resolve(post: this);
}

extension CorporateJobPostDisplayX on CorporateJobPost {
  /// 구버전(합쳐진 summary만 있는 공고) 호환
  String get fullDescriptionText {
    final job = jobDescription.trim();
    final extra = summary.trim();
    if (job.isEmpty) return extra;
    if (extra.isEmpty) return job;
    if (job == extra) return job;
    return '$job\n\n$extra';
  }
}

extension CorporateJobPostStatusX on CorporateJobPostStatus {
  String get label => switch (this) {
        CorporateJobPostStatus.recruiting => '모집중',
        CorporateJobPostStatus.closingSoon => '마감임박',
        CorporateJobPostStatus.closed => '마감',
      };
}
