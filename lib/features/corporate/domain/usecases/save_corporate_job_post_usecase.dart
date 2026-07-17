import 'package:flutter/foundation.dart';
import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/address/services/workplace_address_mismatch_service.dart';
import 'package:map/core/compliance/corporate_verification_access_policy.dart';
import 'package:map/core/compliance/services/abuse_detection_service.dart';
import 'package:map/core/compliance/services/unverified_employer_trial_post_policy.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/sync/job_post_sync_service.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/utils/corporate_job_post_scope.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
import 'package:map/features/corporate/domain/utils/work_schedule_codec.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/work_category/domain/services/work_category_classifier_service.dart';

String formatCorporateHourlyWage(String hourlyWage) {
  final trimmed = hourlyWage.trim();
  if (trimmed.isEmpty) return trimmed;
  final type = parseSalaryPayType(trimmed);
  final digits = salaryPayDigits(trimmed);
  if (digits.isEmpty) return trimmed;
  return type.formatAmount(digits);
}

String formatCorporateDailyWage(int amount) {
  final formatted = amount.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]},',
      );
  return '$formatted원';
}

({
  DateTime? paymentDate,
  SalaryPaymentMonthOffset? paymentMonthOffset,
  int? paymentDayOfMonth,
  bool paymentDateNegotiable,
}) _paymentFieldsFromSchedule(SalaryPaymentSchedule schedule) {
  return switch (schedule) {
    SalaryPaymentAbsoluteDate(:final date) => (
        paymentDate: date,
        paymentMonthOffset: null,
        paymentDayOfMonth: null,
        paymentDateNegotiable: false,
      ),
    SalaryPaymentDailyPerWorkDay(:final dates) => (
        paymentDate: dates.isEmpty ? null : dates.last,
        paymentMonthOffset: null,
        paymentDayOfMonth: null,
        paymentDateNegotiable: false,
      ),
    SalaryPaymentMonthlyRule(:final monthOffset, :final dayOfMonth) => (
        paymentDate: null,
        paymentMonthOffset: monthOffset,
        paymentDayOfMonth: dayOfMonth,
        paymentDateNegotiable: false,
      ),
    SalaryPaymentNegotiable() => (
        paymentDate: null,
        paymentMonthOffset: null,
        paymentDayOfMonth: null,
        paymentDateNegotiable: true,
      ),
  };
}

Future<({double? latitude, double? longitude})> _workplaceCoordinateFields(
  WorkplaceAddress workplace,
) async {
  var coordinate = workplace.coordinate;
  if (coordinate == null && workplace.roadAddress.trim().isNotEmpty) {
    coordinate = await AddressGeocoder.geocode(workplace.roadAddress);
  }
  if (coordinate == null) {
    return (latitude: null, longitude: null);
  }
  return (latitude: coordinate.latitude, longitude: coordinate.longitude);
}

CorporateJobPostResult? _validateWorkSchedule({
  required String workSchedule,
  required WorkerCategory workerCategory,
  bool workPeriodNegotiable = false,
  bool workScheduleNegotiable = false,
}) {
  if (workScheduleNegotiable) return null;
  if (WorkScheduleNegotiable.isLabel(workSchedule)) return null;
  if (workSchedule.trim().isEmpty) {
    return const CorporateJobPostResult.failure('근무 일·시간을 선택해 주세요.');
  }
  if (workerCategory.usesFirstStartDateOnly) {
    final spec = WorkScheduleCodec.tryParse(workSchedule);
    if (spec == null ||
        !spec.isCompleteFor(workPeriodNegotiable: workPeriodNegotiable)) {
      return const CorporateJobPostResult.failure('근무 일·시간을 선택해 주세요.');
    }
  } else if (workerCategory.usesWorkPeriodWithEndDate) {
    final spec = WorkScheduleCodec.tryParse(workSchedule);
    if (spec == null || !spec.isCompleteFor()) {
      return const CorporateJobPostResult.failure(
        '근무 시작일과 종료일을 선택해 주세요.',
      );
    }
  }
  return null;
}

String _normalizedWorkSchedule(
  String workSchedule, {
  required bool workScheduleNegotiable,
}) {
  final trimmed = workSchedule.trim();
  if (workScheduleNegotiable) {
    if (trimmed.isEmpty || WorkScheduleNegotiable.isLabel(trimmed)) {
      return WorkScheduleNegotiable.label;
    }
  }
  return trimmed;
}

({String jobDescription, String summary}) _resolvedDescriptionFields(
  JobPostDescriptionBody body,
) {
  return (
    jobDescription: body.legacyPlainText,
    summary: body.calloutSnippet,
  );
}

CorporateJobPostResult? _validateDescriptionBody(JobPostDescriptionBody body) {
  if (!body.hasContent) {
    return const CorporateJobPostResult.failure('업무 내용을 입력해 주세요.');
  }
  return null;
}

Future<CorporateJobPostResult?> _blockedByUnverifiedTrialLimit(
  CorporateMemberProfile? profile,
) async {
  if (profile == null) return null;
  if (!CorporateVerificationAccessPolicy.isProvisionalMember(profile)) {
    return null;
  }
  final alreadyUsed = await UnverifiedEmployerTrialPostPolicy.hasUsedTrialPost(
    profile.companyKey,
  );
  if (!alreadyUsed) return null;
  return const CorporateJobPostResult.failure(
    '미인증 회원은 무료 공고를 1회(24시간)만 등록할 수 있습니다.\n'
    '사업자등록증을 인증하면 공고를 자유롭게 등록할 수 있어요.',
  );
}

DateTime _expiresAtForNewPost({
  required DateTime postedAt,
  required CorporateMemberProfile? profile,
}) {
  if (profile != null &&
      CorporateVerificationAccessPolicy.isProvisionalMember(profile)) {
    return UnverifiedEmployerTrialPostPolicy.trialExpiresAt(postedAt);
  }
  return JobPostValidity.expiresAtFromRegistration(postedAt);
}

class CreateCorporateJobPostUseCase {
  const CreateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call({
    required String title,
    required WorkplaceAddress workplace,
    required String hourlyWage,
    required String workSchedule,
    required JobPostDescriptionBody descriptionBody,
    required SalaryPaymentSchedule paymentSchedule,
    required WorkerCategory workerCategory,
    JobEmploymentType? employmentType,
    String? dailyWage,
    JobPostNotificationSettings? notificationSettings,
    CorporateMemberProfile? registeredBy,
    JobPostPaymentRecord? paymentRecord,
    String? branchId,
    String? branchName,
    String? commuteRouteId,
    List<String> linkedCommuteRouteIds = const [],
    bool hasShuttleRouteOverlay = false,
    String? workCategoryId,
    bool workPeriodNegotiable = false,
    bool workScheduleNegotiable = false,
    List<ResumeItemKind> requiredResumeItems = const [],
    List<String> requiredCredentialIds = const [],
  }) async {
    final trialBlocked = await _blockedByUnverifiedTrialLimit(registeredBy);
    if (trialBlocked != null) return trialBlocked;
    if (title.trim().isEmpty) {
      return const CorporateJobPostResult.failure('공고 제목을 입력해 주세요.');
    }
    if (workplace.roadAddress.trim().isEmpty) {
      return const CorporateJobPostResult.failure('근무지를 검색해 주세요.');
    }
    final mismatch = WorkplaceAddressMismatchService.evaluate(
      workplace: workplace,
      profile: registeredBy,
    );
    if (hourlyWage.trim().isEmpty || salaryPayDigits(hourlyWage).isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('급여를 입력해 주세요.'),
      );
    }
    if (!workScheduleNegotiable &&
        workSchedule.trim().isEmpty &&
        !WorkScheduleNegotiable.isLabel(workSchedule)) {
      return Future.value(
        const CorporateJobPostResult.failure('근무 일·시간을 선택해 주세요.'),
      );
    }
    final scheduleError = _validateWorkSchedule(
      workSchedule: workSchedule,
      workerCategory: workerCategory,
      workPeriodNegotiable: workPeriodNegotiable,
      workScheduleNegotiable: workScheduleNegotiable,
    );
    if (scheduleError != null) {
      return Future.value(scheduleError);
    }
    final descriptionError = _validateDescriptionBody(descriptionBody);
    if (descriptionError != null) {
      return Future.value(descriptionError);
    }
    final descFields = _resolvedDescriptionFields(descriptionBody);
    if (!paymentSchedule.isComplete) {
      return Future.value(
        const CorporateJobPostResult.failure('급여지급일을 선택해 주세요.'),
      );
    }

    final paymentFields = _paymentFieldsFromSchedule(paymentSchedule);
    final mapPinTier = MapPinTierResolver.resolveForNewPost(
      registeredBy: registeredBy,
      hourlyWage: hourlyWage,
      workSchedule: _normalizedWorkSchedule(
        workSchedule,
        workScheduleNegotiable: workScheduleNegotiable,
      ),
    );

    final resolvedWorkCategoryId = WorkCategoryClassifierService.resolveCategoryId(
      selectedId: workCategoryId,
      title: title.trim(),
      jobDescription: descFields.jobDescription,
      summary: descFields.summary,
    );

    final workplaceCoord = await _workplaceCoordinateFields(workplace);

    final postedAt = DateTime.now();
    final notifyAdminMismatch = !kDebugMode &&
        registeredBy != null &&
        mismatch.notifyAdmin;
    final post = CorporateJobPost(
      id: 'post_${postedAt.millisecondsSinceEpoch}',
      title: title.trim(),
      employmentType: employmentType ?? workerCategory.employmentType,
      workerCategory: workerCategory,
      warehouseName: workplace.displayLabel,
      workplaceLatitude: workplaceCoord.latitude,
      workplaceLongitude: workplaceCoord.longitude,
      hourlyWage: formatCorporateHourlyWage(hourlyWage),
      dailyWage: dailyWage,
      workSchedule: _normalizedWorkSchedule(
        workSchedule,
        workScheduleNegotiable: workScheduleNegotiable,
      ),
      jobDescription: descFields.jobDescription,
      descriptionBody: descriptionBody,
      summary: descFields.summary,
      paymentDate: paymentFields.paymentDate,
      paymentMonthOffset: paymentFields.paymentMonthOffset,
      paymentDayOfMonth: paymentFields.paymentDayOfMonth,
      paymentDateNegotiable: paymentFields.paymentDateNegotiable,
      workPeriodNegotiable: workPeriodNegotiable,
      workScheduleNegotiable: workScheduleNegotiable,
      notificationSettings: notificationSettings,
      registeredBy: registeredBy,
      recruiterEmail: AuthSession.instance.currentUser?.email,
      paymentRecord: paymentRecord,
      branchId: branchId,
      branchName: branchName,
      mapPinDisplayTier: mapPinTier,
      commuteRouteId: commuteRouteId,
      linkedCommuteRouteIds: linkedCommuteRouteIds,
      hasShuttleRouteOverlay: hasShuttleRouteOverlay,
      workCategoryId: resolvedWorkCategoryId,
      requiredResumeItems: requiredResumeItems,
      requiredCredentialIds: requiredCredentialIds,
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: postedAt,
      expiresAt: _expiresAtForNewPost(postedAt: postedAt, profile: registeredBy),
    );

    return _dataSource.createJobPost(post).then((_) async {
      await JobPostSyncService().pushPost(post);
      if (registeredBy != null &&
          CorporateVerificationAccessPolicy.isProvisionalMember(registeredBy)) {
        await UnverifiedEmployerTrialPostPolicy.markTrialPostUsed(
          registeredBy.companyKey,
        );
      }
      if (notifyAdminMismatch) {
        await _reportWorkplaceMismatchForAdmin(
          profile: registeredBy!,
          mismatch: mismatch,
          post: post,
        );
      }
      return CorporateJobPostResult.success(post);
    });
  }
}

class ReactivateCorporateJobPostUseCase {
  const ReactivateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call(
    CorporateJobPost original, {
    CorporateMemberProfile? currentProfile,
  }) async {
    final profile = currentProfile ?? original.registeredBy;
    final blocked = await _blockedByUnverifiedTrialLimit(profile);
    if (blocked != null) return blocked;

    final postedAt = DateTime.now();
    final reactivated = original.copyWith(
      postedAt: postedAt,
      expiresAt: _expiresAtForNewPost(postedAt: postedAt, profile: profile),
      status: CorporateJobPostStatus.recruiting,
    );

    return _dataSource
        .updateJobPost(
          reactivated,
          ownerCompanyKey: CorporateJobPostScope.currentOwnerCompanyKey(),
        )
        .then((_) async {
      await JobPostSyncService().pushPostUpdate(reactivated);
      if (profile != null &&
          CorporateVerificationAccessPolicy.isProvisionalMember(profile)) {
        await UnverifiedEmployerTrialPostPolicy.markTrialPostUsed(
          profile.companyKey,
        );
      }
      return CorporateJobPostResult.success(reactivated);
    });
  }
}

class CloseCorporateJobPostUseCase {
  const CloseCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call(CorporateJobPost post) {
    if (post.status == CorporateJobPostStatus.closed) {
      return Future.value(CorporateJobPostResult.success(post));
    }
    final closed = post.copyWith(status: CorporateJobPostStatus.closed);
    return _dataSource
        .updateJobPost(
          closed,
          ownerCompanyKey: CorporateJobPostScope.currentOwnerCompanyKey(),
        )
        .then((_) async {
      await JobPostSyncService().pushPostUpdate(closed);
      return CorporateJobPostResult.success(closed);
    });
  }
}

class DuplicateCorporateJobPostUseCase {
  const DuplicateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call(
    CorporateJobPost original, {
    CorporateMemberProfile? currentProfile,
  }) async {
    final profile = currentProfile ?? original.registeredBy;
    final blocked = await _blockedByUnverifiedTrialLimit(profile);
    if (blocked != null) return blocked;

    final postedAt = DateTime.now();
    final duplicate = CorporateJobPost(
      id: 'post_${postedAt.millisecondsSinceEpoch}',
      title: original.title,
      employmentType: original.employmentType,
      workerCategory: original.workerCategory,
      warehouseName: original.warehouseName,
      workplaceLatitude: original.workplaceLatitude,
      workplaceLongitude: original.workplaceLongitude,
      hourlyWage: original.hourlyWage,
      dailyWage: original.dailyWage,
      workSchedule: original.workSchedule,
      summary: original.summary,
      jobDescription: original.jobDescription,
      descriptionBody: original.descriptionBody,
      paymentDate: original.paymentDate,
      paymentMonthOffset: original.paymentMonthOffset,
      paymentDayOfMonth: original.paymentDayOfMonth,
      paymentDateNegotiable: original.paymentDateNegotiable,
      workPeriodNegotiable: original.workPeriodNegotiable,
      workScheduleNegotiable: original.workScheduleNegotiable,
      notificationSettings: original.notificationSettings,
      registeredBy: original.registeredBy,
      recruiterEmail: AuthSession.instance.currentUser?.email ??
          original.recruiterEmail,
      branchId: original.branchId,
      branchName: original.branchName,
      mapPinDisplayTier: original.mapPinDisplayTier,
      commuteRouteId: original.commuteRouteId,
      linkedCommuteRouteIds: original.linkedCommuteRouteIds,
      hasShuttleRouteOverlay: original.hasShuttleRouteOverlay,
      workCategoryId: original.workCategoryId,
      requiredResumeItems: original.requiredResumeItems,
      requiredCredentialIds: original.requiredCredentialIds,
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: postedAt,
      expiresAt: _expiresAtForNewPost(postedAt: postedAt, profile: profile),
    );

    return _dataSource.createJobPost(duplicate).then((_) async {
      await JobPostSyncService().pushPost(duplicate);
      if (profile != null &&
          CorporateVerificationAccessPolicy.isProvisionalMember(profile)) {
        await UnverifiedEmployerTrialPostPolicy.markTrialPostUsed(
          profile.companyKey,
        );
      }
      return CorporateJobPostResult.success(duplicate);
    });
  }
}

class UpdateCorporateJobPostUseCase {
  const UpdateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call({
    required CorporateJobPost original,
    required String title,
    required WorkplaceAddress workplace,
    required String hourlyWage,
    required String workSchedule,
    required JobPostDescriptionBody descriptionBody,
    required SalaryPaymentSchedule paymentSchedule,
    required WorkerCategory workerCategory,
    required CorporateJobPostStatus status,
    JobEmploymentType? employmentType,
    String? dailyWage,
    JobPostNotificationSettings? notificationSettings,
    JobPostPaymentRecord? paymentRecord,
    String? branchId,
    String? branchName,
    String? commuteRouteId,
    List<String>? linkedCommuteRouteIds,
    bool? hasShuttleRouteOverlay,
    String? workCategoryId,
    bool workPeriodNegotiable = false,
    bool workScheduleNegotiable = false,
    List<ResumeItemKind>? requiredResumeItems,
    List<String>? requiredCredentialIds,
  }) async {
    if (title.trim().isEmpty) {
      return const CorporateJobPostResult.failure('공고 제목을 입력해 주세요.');
    }
    if (!paymentSchedule.isComplete) {
      return const CorporateJobPostResult.failure('급여지급일을 선택해 주세요.');
    }
    final scheduleError = _validateWorkSchedule(
      workSchedule: workSchedule,
      workerCategory: workerCategory,
      workPeriodNegotiable: workPeriodNegotiable,
      workScheduleNegotiable: workScheduleNegotiable,
    );
    if (scheduleError != null) {
      return scheduleError;
    }
    final mismatch = WorkplaceAddressMismatchService.evaluate(
      workplace: workplace,
      profile: original.registeredBy,
    );

    final notifyAdminMismatch = !kDebugMode &&
        original.registeredBy != null &&
        mismatch.notifyAdmin &&
        status == CorporateJobPostStatus.recruiting;
    final resolvedStatus = status;
    final paymentFields = _paymentFieldsFromSchedule(paymentSchedule);
    final profile = original.registeredBy;
    final mapPinTier = MapPinTierResolver.resolveForNewPost(
      registeredBy: profile,
      hourlyWage: hourlyWage,
      workSchedule: _normalizedWorkSchedule(
        workSchedule,
        workScheduleNegotiable: workScheduleNegotiable,
      ),
    );
    final descriptionError = _validateDescriptionBody(descriptionBody);
    if (descriptionError != null) {
      return Future.value(descriptionError);
    }
    final descFields = _resolvedDescriptionFields(descriptionBody);

    final resolvedWorkCategoryId = WorkCategoryClassifierService.resolveCategoryId(
      selectedId: workCategoryId ?? original.workCategoryId,
      title: title.trim(),
      jobDescription: descFields.jobDescription,
      summary: descFields.summary,
    );

    final workplaceCoord = await _workplaceCoordinateFields(workplace);

    final updated = CorporateJobPost(
      id: original.id,
      title: title.trim(),
      employmentType: employmentType ?? workerCategory.employmentType,
      workerCategory: workerCategory,
      warehouseName: workplace.displayLabel,
      workplaceLatitude: workplaceCoord.latitude,
      workplaceLongitude: workplaceCoord.longitude,
      hourlyWage: formatCorporateHourlyWage(hourlyWage),
      dailyWage: dailyWage ?? original.dailyWage,
      workSchedule: _normalizedWorkSchedule(
        workSchedule,
        workScheduleNegotiable: workScheduleNegotiable,
      ),
      jobDescription: descFields.jobDescription,
      descriptionBody: descriptionBody,
      summary: descFields.summary,
      paymentDate: paymentFields.paymentDate,
      paymentMonthOffset: paymentFields.paymentMonthOffset,
      paymentDayOfMonth: paymentFields.paymentDayOfMonth,
      paymentDateNegotiable: paymentFields.paymentDateNegotiable,
      workPeriodNegotiable: workPeriodNegotiable,
      workScheduleNegotiable: workScheduleNegotiable,
      notificationSettings: notificationSettings,
      registeredBy: original.registeredBy,
      recruiterEmail: original.recruiterEmail,
      paymentRecord: paymentRecord ?? original.paymentRecord,
      branchId: branchId ?? original.branchId,
      branchName: branchName ?? original.branchName,
      mapPinDisplayTier: mapPinTier,
      commuteRouteId: commuteRouteId ?? original.commuteRouteId,
      linkedCommuteRouteIds:
          linkedCommuteRouteIds ?? original.linkedCommuteRouteIds,
      shuttleRegisteredStopIdsByRoute: original.shuttleRegisteredStopIdsByRoute,
      shuttlePaidStopIdsByRoute: original.shuttlePaidStopIdsByRoute,
      shuttleExposurePaidAt: original.shuttleExposurePaidAt,
      hasShuttleRouteOverlay:
          hasShuttleRouteOverlay ?? original.hasShuttleRouteOverlay,
      workCategoryId: resolvedWorkCategoryId,
      requiredResumeItems:
          requiredResumeItems ?? original.requiredResumeItems,
      requiredCredentialIds:
          requiredCredentialIds ?? original.requiredCredentialIds,
      status: resolvedStatus,
      applicantCount: original.applicantCount,
      postedAt: original.postedAt,
      expiresAt: original.expiresAt,
    );

    return _dataSource
        .updateJobPost(
          updated,
          ownerCompanyKey: CorporateJobPostScope.currentOwnerCompanyKey(),
        )
        .then((_) async {
      await JobPostSyncService().pushPostUpdate(updated);
      if (notifyAdminMismatch) {
        await _reportWorkplaceMismatchForAdmin(
          profile: original.registeredBy!,
          mismatch: mismatch,
          post: updated,
        );
      }
      return CorporateJobPostResult.success(updated);
    });
  }
}

Future<void> _reportWorkplaceMismatchForAdmin({
  required CorporateMemberProfile profile,
  required WorkplaceAddressMismatchResult mismatch,
  required CorporateJobPost post,
}) async {
  final reason = mismatch.reason ??
      '실근무지와 사업자 소재지가 다릅니다. 어드민 검토 대상입니다.';
  await AbuseDetectionService().reportWorkplaceMismatch(
    companyKey: profile.companyKey,
    companyName: profile.companyName,
    headOfficeAddress: mismatch.headOfficeAddress ?? '',
    workplaceAddress: mismatch.workplaceAddress ?? '',
    reason: reason,
    distanceMeters: mismatch.distanceMeters,
    postId: post.id,
    postTitle: post.title,
  );
}

class CorporateJobPostResult {
  const CorporateJobPostResult._({
    required this.isSuccess,
    this.isPendingReview = false,
    this.message,
    this.post,
  });

  const CorporateJobPostResult.success(CorporateJobPost post)
      : this._(isSuccess: true, post: post);

  const CorporateJobPostResult.pendingReview(
    CorporateJobPost post, {
    String? message,
  }) : this._(
          isSuccess: false,
          isPendingReview: true,
          post: post,
          message: message,
        );

  const CorporateJobPostResult.failure(String message)
      : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final bool isPendingReview;
  final String? message;
  final CorporateJobPost? post;
}
