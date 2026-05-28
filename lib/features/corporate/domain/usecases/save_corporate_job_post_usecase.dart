import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';
import 'package:map/features/corporate/domain/entities/salary_pay_type.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

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
}) _paymentFieldsFromSchedule(SalaryPaymentSchedule schedule) {
  return switch (schedule) {
    SalaryPaymentAbsoluteDate(:final date) => (
        paymentDate: date,
        paymentMonthOffset: null,
        paymentDayOfMonth: null,
      ),
    SalaryPaymentMonthlyRule(:final monthOffset, :final dayOfMonth) => (
        paymentDate: null,
        paymentMonthOffset: monthOffset,
        paymentDayOfMonth: dayOfMonth,
      ),
  };
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
  }) {
    if (title.trim().isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('공고 제목을 입력해 주세요.'),
      );
    }
    if (workplace.roadAddress.trim().isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('근무지를 검색해 주세요.'),
      );
    }
    if (hourlyWage.trim().isEmpty ||
        salaryPayDigits(hourlyWage).isEmpty) {
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
    final extraSummary = summary.trim();
    if (jobDesc.isEmpty && extraSummary.isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('업무 내용 또는 내용 추가를 입력해 주세요.'),
      );
    }
    if (!paymentSchedule.isComplete) {
      return Future.value(
        const CorporateJobPostResult.failure('급여지급일을 선택해 주세요.'),
      );
    }

    final paymentFields = _paymentFieldsFromSchedule(paymentSchedule);
    final mapPinTier = MapPinTierResolver.resolveForNewPost(
      registeredBy: registeredBy,
    );

    final post = CorporateJobPost(
      id: 'post_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      employmentType: employmentType ?? workerCategory.employmentType,
      workerCategory: workerCategory,
      warehouseName: workplace.displayLabel,
      hourlyWage: formatCorporateHourlyWage(hourlyWage),
      dailyWage: dailyWage,
      workSchedule: workSchedule.trim(),
      jobDescription: jobDesc,
      summary: extraSummary,
      paymentDate: paymentFields.paymentDate,
      paymentMonthOffset: paymentFields.paymentMonthOffset,
      paymentDayOfMonth: paymentFields.paymentDayOfMonth,
      notificationSettings: notificationSettings,
      registeredBy: registeredBy,
      paymentRecord: paymentRecord,
      branchId: branchId,
      branchName: branchName,
      mapPinDisplayTier: mapPinTier,
      status: CorporateJobPostStatus.recruiting,
      applicantCount: 0,
      postedAt: DateTime.now(),
    );

    return _dataSource.createJobPost(post).then(
          (_) => CorporateJobPostResult.success(post),
        );
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
  }) {
    if (title.trim().isEmpty) {
      return Future.value(
        const CorporateJobPostResult.failure('공고 제목을 입력해 주세요.'),
      );
    }
    if (!paymentSchedule.isComplete) {
      return Future.value(
        const CorporateJobPostResult.failure('급여지급일을 선택해 주세요.'),
      );
    }

    final paymentFields = _paymentFieldsFromSchedule(paymentSchedule);
    final profile = original.registeredBy;
    final mapPinTier = MapPinTierResolver.resolveForNewPost(
      registeredBy: profile,
    );

    final updated = CorporateJobPost(
      id: original.id,
      title: title.trim(),
      employmentType: employmentType ?? workerCategory.employmentType,
      workerCategory: workerCategory,
      warehouseName: workplace.displayLabel,
      hourlyWage: formatCorporateHourlyWage(hourlyWage),
      dailyWage: dailyWage ?? original.dailyWage,
      workSchedule: workSchedule.trim(),
      jobDescription: jobDescription.trim(),
      summary: summary.trim(),
      paymentDate: paymentFields.paymentDate,
      paymentMonthOffset: paymentFields.paymentMonthOffset,
      paymentDayOfMonth: paymentFields.paymentDayOfMonth,
      notificationSettings: notificationSettings,
      registeredBy: original.registeredBy,
      paymentRecord: paymentRecord ?? original.paymentRecord,
      branchId: branchId ?? original.branchId,
      branchName: branchName ?? original.branchName,
      mapPinDisplayTier: mapPinTier,
      status: status,
      applicantCount: original.applicantCount,
      postedAt: original.postedAt,
    );

    return _dataSource.updateJobPost(updated).then(
          (_) => CorporateJobPostResult.success(updated),
        );
  }
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
