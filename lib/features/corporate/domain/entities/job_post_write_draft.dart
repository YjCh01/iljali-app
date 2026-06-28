import 'package:map/core/constants/labor_constants.dart';

import 'package:map/features/corporate/domain/entities/job_post_description_body.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/entities/salary_payment_schedule.dart';

import 'package:map/features/corporate/domain/entities/worker_category.dart';

import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';



/// 일자리 작성 폼 초기값

class JobPostWriteDraft {

  const JobPostWriteDraft({

    this.title = '',

    this.workplaceAddress,

    this.jobDescription = '',

    this.descriptionBody = const JobPostDescriptionBody(),

    this.hourlyWage = LaborConstants.defaultHourlyWageText,

    this.workSchedule = '',

    this.summary = '',

    this.employmentType = JobEmploymentType.daily,

    this.workerCategory = WorkerCategory.general,

    this.paymentDate,

    this.paymentMonthOffset,

    this.paymentDayOfMonth,

    this.workPeriodNegotiable = false,

    this.notificationSettings,

    this.importSourceLabel,

    this.workCategoryId,

    this.requiredResumeItems = const [],

    this.requiredCredentialIds = const [],

  });



  final String title;

  final String? workplaceAddress;

  final String jobDescription;

  final JobPostDescriptionBody descriptionBody;

  final String hourlyWage;

  final String workSchedule;

  final String summary;

  final JobEmploymentType employmentType;

  final WorkerCategory workerCategory;

  final DateTime? paymentDate;

  final SalaryPaymentMonthOffset? paymentMonthOffset;

  final int? paymentDayOfMonth;

  final bool workPeriodNegotiable;

  final JobPostNotificationSettings? notificationSettings;

  /// 외부 플랫폼 가져오기 출처 (예: 알바몬에서 가져옴)
  final String? importSourceLabel;

  final String? workCategoryId;

  final List<ResumeItemKind> requiredResumeItems;

  final List<String> requiredCredentialIds;



  JobPostWriteDraft copyWith({

    String? title,

    String? workplaceAddress,

    String? jobDescription,

    String? hourlyWage,

    String? workSchedule,

    String? summary,

    DateTime? paymentDate,

    SalaryPaymentMonthOffset? paymentMonthOffset,

    int? paymentDayOfMonth,

    bool? workPeriodNegotiable,

    JobPostNotificationSettings? notificationSettings,

    JobEmploymentType? employmentType,

    WorkerCategory? workerCategory,

    String? importSourceLabel,

    String? workCategoryId,

    List<ResumeItemKind>? requiredResumeItems,

    List<String>? requiredCredentialIds,

  }) {

    return JobPostWriteDraft(

      title: title ?? this.title,

      workplaceAddress: workplaceAddress ?? this.workplaceAddress,

      jobDescription: jobDescription ?? this.jobDescription,

      hourlyWage: hourlyWage ?? this.hourlyWage,

      workSchedule: workSchedule ?? this.workSchedule,

      summary: summary ?? this.summary,

      employmentType: employmentType ?? this.employmentType,

      workerCategory: workerCategory ?? this.workerCategory,

      paymentDate: paymentDate ?? this.paymentDate,

      paymentMonthOffset: paymentMonthOffset ?? this.paymentMonthOffset,

      paymentDayOfMonth: paymentDayOfMonth ?? this.paymentDayOfMonth,

      workPeriodNegotiable: workPeriodNegotiable ?? this.workPeriodNegotiable,

      notificationSettings: notificationSettings ?? this.notificationSettings,

      importSourceLabel: importSourceLabel ?? this.importSourceLabel,

      workCategoryId: workCategoryId ?? this.workCategoryId,

      requiredResumeItems:
          requiredResumeItems ?? this.requiredResumeItems,

      requiredCredentialIds:
          requiredCredentialIds ?? this.requiredCredentialIds,

    );

  }

}

