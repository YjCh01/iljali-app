import 'package:flutter/foundation.dart';
import 'package:map/core/address/address_geocoder.dart';
import 'package:map/core/address/services/workplace_address_mismatch_service.dart';
import 'package:map/core/compliance/services/abuse_detection_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/sync/job_post_sync_service.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/domain/utils/job_post_validity.dart';
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

class CreateCorporateJobPostUseCase {
  const CreateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call({
    required String title,
    required WorkplaceAddress workplace,
    required String hourlyWage,
    required String workSchedule,
    required String summary,
    String jobDescription = '',
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
  }) async {
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
    if (!mismatch.allowed && registeredBy != null && !kDebugMode) {
      final headOffice = registeredBy.businessHeadOfficeAddress?.trim();
      if (headOffice == null || headOffice.isEmpty) {
        return Future.value(
          CorporateJobPostResult.failure(
            mismatch.reason ??
                '사업자 본사 주소를 먼저 등록해야 공고를 올릴 수 있습니다.',
          ),
        );
      }
      return _blockWorkplaceMismatch(
        profile: registeredBy,
        mismatch: mismatch,
      );
    }
    if (hourlyWage.trim().isEmpty || salaryPayDigits(hourlyWage).isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('급여를 입력해 주세요.'),
      );
    }
    if (workSchedule.trim().isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('근무 일·시간을 선택해 주세요.'),
      );
    }
    final jobDesc = jobDescription.trim();
    if (jobDesc.isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('업무 내용을 입력해 주세요.'),
      );
    }
    final resolvedSummary =
        summary.trim().isEmpty ? jobDesc : summary.trim();
    if (!paymentSchedule.isComplete) {
      return Future.value(
        const CorporateJobPostResult.failure('급여지급일을 선택해 주세요.'),
      );
    }

    final paymentFields = _paymentFieldsFromSchedule(paymentSchedule);
    final mapPinTier = MapPinTierResolver.resolveForNewPost(
      registeredBy: registeredBy,
      hourlyWage: hourlyWage,
      workSchedule: workSchedule.trim(),
    );

    final resolvedWorkCategoryId = WorkCategoryClassifierService.resolveCategoryId(
      selectedId: workCategoryId,
      title: title.trim(),
      jobDescription: jobDesc,
      summary: resolvedSummary,
    );

    final workplaceCoord = await _workplaceCoordinateFields(workplace);

    final postedAt = DateTime.now();
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
      workSchedule: workSchedule.trim(),
      jobDescription: jobDesc,
      summary: resolvedSummary,
      paymentDate: paymentFields.paymentDate,
      paymentMonthOffset: paymentFields.paymentMonthOffset,
      paymentDayOfMonth: paymentFields.paymentDayOfMonth,
      paymentDateNegotiable: paymentFields.paymentDateNegotiable,
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
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: postedAt,
      expiresAt: JobPostValidity.expiresAtFromRegistration(postedAt),
    );

    return _dataSource.createJobPost(post).then((_) async {
      await JobPostSyncService().pushPost(post);
      return CorporateJobPostResult.success(post);
    });
  }
}

class ReactivateCorporateJobPostUseCase {
  const ReactivateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call(CorporateJobPost original) {
    final postedAt = DateTime.now();
    final reactivated = original.copyWith(
      postedAt: postedAt,
      expiresAt: JobPostValidity.expiresAtFromRegistration(postedAt),
      status: CorporateJobPostStatus.recruiting,
    );

    return _dataSource.updateJobPost(reactivated).then((_) async {
      await JobPostSyncService().pushPostUpdate(reactivated);
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
    return _dataSource.updateJobPost(closed).then((_) async {
      await JobPostSyncService().pushPostUpdate(closed);
      return CorporateJobPostResult.success(closed);
    });
  }
}

class DuplicateCorporateJobPostUseCase {
  const DuplicateCorporateJobPostUseCase(this._dataSource);

  final CorporateJobPostLocalDataSource _dataSource;

  Future<CorporateJobPostResult> call(CorporateJobPost original) {
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
      paymentDate: original.paymentDate,
      paymentMonthOffset: original.paymentMonthOffset,
      paymentDayOfMonth: original.paymentDayOfMonth,
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
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: postedAt,
      expiresAt: JobPostValidity.expiresAtFromRegistration(postedAt),
    );

    return _dataSource.createJobPost(duplicate).then((_) async {
      await JobPostSyncService().pushPost(duplicate);
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
    required String summary,
    String jobDescription = '',
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
  }) async {
    if (title.trim().isEmpty) {
      return const CorporateJobPostResult.failure('공고 제목을 입력해 주세요.');
    }
    if (!paymentSchedule.isComplete) {
      return const CorporateJobPostResult.failure('급여지급일을 선택해 주세요.');
    }
    final mismatch = WorkplaceAddressMismatchService.evaluate(
      workplace: workplace,
      profile: original.registeredBy,
    );
    if (!mismatch.allowed && original.registeredBy != null && !kDebugMode) {
      final headOffice =
          original.registeredBy!.businessHeadOfficeAddress?.trim();
      if (headOffice == null || headOffice.isEmpty) {
        return Future.value(
          CorporateJobPostResult.failure(
            mismatch.reason ??
                '사업자 본사 주소를 먼저 등록해야 공고를 올릴 수 있습니다.',
          ),
        );
      }
      return _blockWorkplaceMismatch(
        profile: original.registeredBy!,
        mismatch: mismatch,
      );
    }

    final paymentFields = _paymentFieldsFromSchedule(paymentSchedule);
    final profile = original.registeredBy;
    final mapPinTier = MapPinTierResolver.resolveForNewPost(
      registeredBy: profile,
      hourlyWage: hourlyWage,
      workSchedule: workSchedule.trim(),
    );
    final jobDesc = jobDescription.trim();
    if (jobDesc.isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('업무 내용을 입력해 주세요.'),
      );
    }
    final resolvedSummary =
        summary.trim().isEmpty ? jobDesc : summary.trim();

    final resolvedWorkCategoryId = WorkCategoryClassifierService.resolveCategoryId(
      selectedId: workCategoryId ?? original.workCategoryId,
      title: title.trim(),
      jobDescription: jobDesc,
      summary: resolvedSummary,
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
      workSchedule: workSchedule.trim(),
      jobDescription: jobDesc,
      summary: resolvedSummary,
      paymentDate: paymentFields.paymentDate,
      paymentMonthOffset: paymentFields.paymentMonthOffset,
      paymentDayOfMonth: paymentFields.paymentDayOfMonth,
      paymentDateNegotiable: paymentFields.paymentDateNegotiable,
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
      status: status,
      applicantCount: original.applicantCount,
      postedAt: original.postedAt,
      expiresAt: original.expiresAt,
    );

    return _dataSource.updateJobPost(updated).then((_) async {
      await JobPostSyncService().pushPostUpdate(updated);
      return CorporateJobPostResult.success(updated);
    });
  }
}

Future<CorporateJobPostResult> _blockWorkplaceMismatch({
  required CorporateMemberProfile profile,
  required WorkplaceAddressMismatchResult mismatch,
}) async {
  final reason = mismatch.reason ?? '사업자 본사 주소와 근무지가 일치하지 않아 공고 노출이 제한됩니다.';
  final restricted = profile.copyWith(
    requiresAdminReview: true,
    adminReviewApproved: false,
    adminReviewReason: reason,
  );
  await AuthSession.instance.updateCorporateProfile(restricted);
  await AbuseDetectionService().reportWorkplaceMismatch(
    companyKey: profile.companyKey,
    headOfficeAddress: mismatch.headOfficeAddress ?? '',
    workplaceAddress: mismatch.workplaceAddress ?? '',
    reason: reason,
    distanceMeters: mismatch.distanceMeters,
  );
  return CorporateJobPostResult.failure(reason);
}

class CorporateJobPostResult {
  const CorporateJobPostResult._({
    required this.isSuccess,
    this.message,
    this.post,
  });

  const CorporateJobPostResult.success(CorporateJobPost post)
      : this._(isSuccess: true, post: post);

  const CorporateJobPostResult.failure(String message)
      : this._(isSuccess: false, message: message);

  final bool isSuccess;
  final String? message;
  final CorporateJobPost? post;
}
